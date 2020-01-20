/*-------------------------------------------------------------------------
 *
 * intermediate_result_pruning.c
 *   Functions for pruning intermediate result broadcasting.
 *
 * We only send intermediate results of subqueries and CTEs to worker nodes
 * that use them in the remainder of the distributed plan to avoid unnecessary
 * network traffic.
 *
 * Copyright (c) Citus Data, Inc.
 *
 *-------------------------------------------------------------------------
 */

#include "distributed/citus_custom_scan.h"
#include "distributed/intermediate_result_pruning.h"
#include "distributed/listutils.h"
#include "distributed/log_utils.h"
#include "distributed/metadata_cache.h"
#include "distributed/query_utils.h"
#include "distributed/worker_manager.h"
#include "utils/builtins.h"

/* controlled via GUC, used mostly for testing */
bool LogIntermediateResults = false;

static List * AppendAllAccessedWorkerNodes(IntermediateResultsHashEntry *entry,
										   DistributedPlan *distributedPlan,
										   int workerNodeCount);


/*
 * FindSubPlansUsedInPlan finds all the subplans used by the plan by traversing
 * the range table entries in the plan.
 */
List *
FindSubPlansUsedInNode(Node *node)
{
	List *rangeTableList = NIL;
	ListCell *rangeTableCell = NULL;
	List *usedSubPlanList = NIL;

	ExtractRangeTableEntryWalker(node, &rangeTableList);

	foreach(rangeTableCell, rangeTableList)
	{
		RangeTblEntry *rangeTableEntry = lfirst(rangeTableCell);
		if (rangeTableEntry->rtekind == RTE_FUNCTION)
		{
			char *resultId =
				FindIntermediateResultIdIfExists(rangeTableEntry);

			if (resultId == NULL)
			{
				continue;
			}

			/*
			 * Use a Value to be able to use list_append_unique and store
			 * the result ID in the DistributedPlan.
			 */
			Value *resultIdValue = makeString(resultId);

			usedSubPlanList = list_append_unique(usedSubPlanList, resultIdValue);
		}
	}

	return usedSubPlanList;
}


/*
 * RecordSubplanExecutionsOnNodes iterates over the usedSubPlanNodeList,
 * and for each entry, record the workerNodes that are accessed by
 * the distributed plan.
 *
 * Later, we'll use this information while we broadcast the intermediate
 * results to the worker nodes. The idea is that the intermediate result
 * should only be broadcasted to the worker nodes that are accessed by
 * the distributedPlan(s) that the subPlan is used in.
 *
 * Finally, the function recursively descends into the actual subplans
 * of the input distributedPlan as well.
 */
void
RecordSubplanExecutionsOnNodes(HTAB *intermediateResultsHash,
							   DistributedPlan *distributedPlan)
{
	Value *usedSubPlanIdValue = NULL;
	List *usedSubPlanNodeList = distributedPlan->usedSubPlanNodeList;
	List *subPlanList = distributedPlan->subPlanList;
	ListCell *subPlanCell = NULL;
	int workerNodeCount = GetWorkerNodeCount();

	foreach_ptr(usedSubPlanIdValue, usedSubPlanNodeList)
	{
		char *resultId = strVal(usedSubPlanIdValue);

		IntermediateResultsHashEntry *entry = SearchIntermediateResult(
			intermediateResultsHash, resultId);

		/*
		 * There is no need to traverse the whole plan if the intermediate result
		 * will be written to a local file and send to all nodes
		 */
		if (list_length(entry->nodeIdList) == workerNodeCount && entry->writeLocalFile)
		{
			elog(DEBUG4, "Subplan %s is used in all workers", resultId);
			break;
		}
		else
		{
			/*
			 * traverse the plan and add find all worker nodes
			 *
			 * If we have reference tables in the distributed plan, all the
			 * workers will be in the node list. We can improve intermediate result
			 * pruning by deciding which reference table shard will be accessed earlier
			 */
			entry->nodeIdList = AppendAllAccessedWorkerNodes(entry, distributedPlan,
															 workerNodeCount);

			elog(DEBUG4, "Subplan %s is used in plan %lu", resultId,
				 distributedPlan->planId);
		}
	}

	/* descend into the subPlans */
	foreach(subPlanCell, subPlanList)
	{
		DistributedSubPlan *subPlan = (DistributedSubPlan *) lfirst(subPlanCell);
		CustomScan *customScan = FetchCitusCustomScanIfExists(subPlan->plan->planTree);
		if (customScan)
		{
			DistributedPlan *distributedPlanOfSubPlan = GetDistributedPlan(customScan);
			RecordSubplanExecutionsOnNodes(intermediateResultsHash,
										   distributedPlanOfSubPlan);
		}
	}
}


/*
 * AppendAllAccessedWorkerNodes iterates over all the tasks in a distributed plan
 * to create the list of worker nodes that can be accessed when this plan is executed.
 *
 * If there are multiple placements of a Shard, all of them are considered and
 * all the workers with placements are appended to the list. This effectively
 * means that if there is a reference table access in the distributed plan, all
 * the workers will be in the resulting list.
 *
 * If there exists any tasks that can be locally executed, we set a flag to
 * indicate that the file should be written to local as well
 */
static List *
AppendAllAccessedWorkerNodes(IntermediateResultsHashEntry *entry,
							 DistributedPlan *distributedPlan, int workerNodeCount)
{
	List *workerNodeList = entry->nodeIdList;
	List *taskList = distributedPlan->workerJob->taskList;
	ListCell *taskCell = NULL;

	foreach(taskCell, taskList)
	{
		Task *task = lfirst(taskCell);
		ListCell *placementCell = NULL;
		foreach(placementCell, task->taskPlacementList)
		{
			ShardPlacement *placement = lfirst(placementCell);
			workerNodeList = list_append_unique_int(workerNodeList, placement->nodeId);

			if (placement->groupId == GetLocalGroupId())
			{
				entry->writeLocalFile = true;
			}

			/* early return if all the workers are accessed, and the result is written to local file */
			if (list_length(workerNodeList) == workerNodeCount && entry->writeLocalFile)
			{
				return workerNodeList;
			}
		}
	}

	return workerNodeList;
}


/*
 * MakeIntermediateResultHTAB is a helper method that creates a Hash Table that
 * stores information on the intermediate result.
 */
HTAB *
MakeIntermediateResultHTAB()
{
	HASHCTL info = { 0 };
	int initialNumberOfElements = 16;

	info.keysize = NAMEDATALEN;
	info.entrysize = sizeof(IntermediateResultsHashEntry);
	info.hash = string_hash;
	info.hcxt = CurrentMemoryContext;
	uint32 hashFlags = (HASH_ELEM | HASH_FUNCTION | HASH_CONTEXT);

	HTAB *intermediateResultsHash = hash_create("Intermediate results hash",
												initialNumberOfElements, &info,
												hashFlags);

	return intermediateResultsHash;
}


/*
 * FindAllWorkerNodesUsingSubplan creates a list of worker nodes that
 * may need to access subplan results, and decides if these results should be
 * written to a local file
 */
List *
FindAllWorkerNodesUsingSubplan(IntermediateResultsHashEntry *entry,
							   char *resultId)
{
	List *workerNodeList = NIL;
	ListCell *nodeIdCell = NULL;
	foreach(nodeIdCell, entry->nodeIdList)
	{
		uint32 nodeId = lfirst_int(nodeIdCell);

		/*
		 * If we have a dummy placement, intermediate plan will be written locally.
		 * Note that we do not skip the loop when entry->writeLocalFile, because
		 * even though the entry is local, it might still be required to broadcast to
		 * remote nodes.
		 */
		if (nodeId == DUMMY_NODE_ID)
		{
			entry->writeLocalFile = true;
			continue;
		}

		WorkerNode *workerNode = LookupNodeByNodeId(nodeId);
		Assert(workerNode != NULL);

		workerNodeList = lappend(workerNodeList, workerNode);
	}

	/* don't include the current worker if the result will be written to local file */
	if (entry->writeLocalFile)
	{
		WorkerNode *workerNode = NULL;
		int32 localGroupId = GetLocalGroupId();

		/* we'll iterate over the list while deleting from it, so copy it */
		List *copyOfWorkerNodeList = list_copy(workerNodeList);
		foreach_ptr(workerNode, copyOfWorkerNodeList)
		{
			if (workerNode->groupId == localGroupId)
			{
				workerNodeList = list_delete_ptr(workerNodeList, workerNode);
				break;
			}
		}
	}

	/* now, log the summary */
	if ((LogIntermediateResults && IsLoggableLevel(DEBUG1)) ||
		IsLoggableLevel(DEBUG4))
	{
		if (entry->writeLocalFile || workerNodeList == NIL)
		{
			elog(DEBUG1, "Subplan %s will be written to local file", resultId);
		}

		WorkerNode *workerNode = NULL;
		foreach_ptr(workerNode, workerNodeList)
		{
			elog(DEBUG1, "Subplan %s will be sent to %s:%d", resultId,
				 workerNode->workerName, workerNode->workerPort);
		}
	}

	return workerNodeList;
}


/*
 * SearchIntermediateResult searches through intermediateResultsHash for a given
 * intermediate result id.
 *
 * If an entry is not found, creates a new entry with sane defaults.
 */
IntermediateResultsHashEntry *
SearchIntermediateResult(HTAB *intermediateResultsHash, char *resultId)
{
	bool found = false;

	IntermediateResultsHashEntry *entry = hash_search(intermediateResultsHash, resultId,
													  HASH_ENTER, &found);

	/* use sane defaults */
	if (!found)
	{
		entry->writeLocalFile = false;
		entry->nodeIdList = NIL;
	}

	return entry;
}
