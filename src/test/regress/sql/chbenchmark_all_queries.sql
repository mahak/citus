SET citus.next_shard_id TO 1650000;
CREATE SCHEMA chbenchmark_all_queries;
SET search_path TO chbenchmark_all_queries;

-- we want to make sure the join order is stable. If the join order of a table changes due
-- to a chacnge you are making, please verify if it is not a regression. If the join order
-- became better feel free to update the output.
SET citus.log_multi_join_order TO on;
SET client_min_messages TO log;

SET citus.enable_repartition_joins TO on;
CREATE TABLE order_line (
    ol_w_id int NOT NULL,
    ol_d_id int NOT NULL,
    ol_o_id int NOT NULL,
    ol_number int NOT NULL,
    ol_i_id int NOT NULL,
    ol_delivery_d timestamp NULL DEFAULT NULL,
    ol_amount decimal(6,2) NOT NULL,
    ol_supply_w_id int NOT NULL,
    ol_quantity decimal(2,0) NOT NULL,
    ol_dist_info char(24) NOT NULL,
    PRIMARY KEY (ol_w_id,ol_d_id,ol_o_id,ol_number)
);
CREATE TABLE new_order (
    no_w_id int NOT NULL,
    no_d_id int NOT NULL,
    no_o_id int NOT NULL,
    PRIMARY KEY (no_w_id,no_d_id,no_o_id)
);
CREATE TABLE stock (
    s_w_id int NOT NULL,
    s_i_id int NOT NULL,
    s_quantity decimal(4,0) NOT NULL,
    s_ytd decimal(8,2) NOT NULL,
    s_order_cnt int NOT NULL,
    s_remote_cnt int NOT NULL,
    s_data varchar(50) NOT NULL,
    s_dist_01 char(24) NOT NULL,
    s_dist_02 char(24) NOT NULL,
    s_dist_03 char(24) NOT NULL,
    s_dist_04 char(24) NOT NULL,
    s_dist_05 char(24) NOT NULL,
    s_dist_06 char(24) NOT NULL,
    s_dist_07 char(24) NOT NULL,
    s_dist_08 char(24) NOT NULL,
    s_dist_09 char(24) NOT NULL,
    s_dist_10 char(24) NOT NULL,
    PRIMARY KEY (s_w_id,s_i_id)
);
CREATE TABLE oorder (
    o_w_id int NOT NULL,
    o_d_id int NOT NULL,
    o_id int NOT NULL,
    o_c_id int NOT NULL,
    o_carrier_id int DEFAULT NULL,
    o_ol_cnt decimal(2,0) NOT NULL,
    o_all_local decimal(1,0) NOT NULL,
    o_entry_d timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (o_w_id,o_d_id,o_id),
    UNIQUE (o_w_id,o_d_id,o_c_id,o_id)
);
CREATE TABLE history (
    h_c_id int NOT NULL,
    h_c_d_id int NOT NULL,
    h_c_w_id int NOT NULL,
    h_d_id int NOT NULL,
    h_w_id int NOT NULL,
    h_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    h_amount decimal(6,2) NOT NULL,
    h_data varchar(24) NOT NULL
);
CREATE TABLE customer (
    c_w_id int NOT NULL,
    c_d_id int NOT NULL,
    c_id int NOT NULL,
    c_discount decimal(4,4) NOT NULL,
    c_credit char(2) NOT NULL,
    c_last varchar(16) NOT NULL,
    c_first varchar(16) NOT NULL,
    c_credit_lim decimal(12,2) NOT NULL,
    c_balance decimal(12,2) NOT NULL,
    c_ytd_payment float NOT NULL,
    c_payment_cnt int NOT NULL,
    c_delivery_cnt int NOT NULL,
    c_street_1 varchar(20) NOT NULL,
    c_street_2 varchar(20) NOT NULL,
    c_city varchar(20) NOT NULL,
    c_state char(2) NOT NULL,
    c_zip char(9) NOT NULL,
    c_phone char(16) NOT NULL,
    c_since timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    c_middle char(2) NOT NULL,
    c_data varchar(500) NOT NULL,
    PRIMARY KEY (c_w_id,c_d_id,c_id)
);
CREATE TABLE district (
    d_w_id int NOT NULL,
    d_id int NOT NULL,
    d_ytd decimal(12,2) NOT NULL,
    d_tax decimal(4,4) NOT NULL,
    d_next_o_id int NOT NULL,
    d_name varchar(10) NOT NULL,
    d_street_1 varchar(20) NOT NULL,
    d_street_2 varchar(20) NOT NULL,
    d_city varchar(20) NOT NULL,
    d_state char(2) NOT NULL,
    d_zip char(9) NOT NULL,
    PRIMARY KEY (d_w_id,d_id)
);
CREATE TABLE item (
    i_id int NOT NULL,
    i_name varchar(24) NOT NULL,
    i_price decimal(5,2) NOT NULL,
    i_data varchar(50) NOT NULL,
    i_im_id int NOT NULL,
    PRIMARY KEY (i_id)
);
CREATE TABLE warehouse (
    w_id int NOT NULL,
    w_ytd decimal(12,2) NOT NULL,
    w_tax decimal(4,4) NOT NULL,
    w_name varchar(10) NOT NULL,
    w_street_1 varchar(20) NOT NULL,
    w_street_2 varchar(20) NOT NULL,
    w_city varchar(20) NOT NULL,
    w_state char(2) NOT NULL,
    w_zip char(9) NOT NULL,
    PRIMARY KEY (w_id)
);
CREATE TABLE region (
    r_regionkey int not null,
    r_name char(55) not null,
    r_comment char(152) not null,
    PRIMARY KEY ( r_regionkey )
);
CREATE TABLE nation (
    n_nationkey int not null,
    n_name char(25) not null,
    n_regionkey int not null,
    n_comment char(152) not null,
    PRIMARY KEY ( n_nationkey )
);
CREATE TABLE supplier (
    su_suppkey int not null,
    su_name char(25) not null,
    su_address varchar(40) not null,
    su_nationkey int not null,
    su_phone char(15) not null,
    su_acctbal numeric(12,2) not null,
    su_comment char(101) not null,
    PRIMARY KEY ( su_suppkey )
);

SELECT create_distributed_table('order_line','ol_w_id');
SELECT create_distributed_table('new_order','no_w_id');
SELECT create_distributed_table('stock','s_w_id');
SELECT create_distributed_table('oorder','o_w_id');
SELECT create_distributed_table('history','h_w_id');
SELECT create_distributed_table('customer','c_w_id');
SELECT create_distributed_table('district','d_w_id');
SELECT create_distributed_table('warehouse','w_id');
SELECT create_reference_table('item');
SELECT create_reference_table('region');
SELECT create_reference_table('nation');
SELECT create_reference_table('supplier');

TRUNCATE order_line, new_order, stock, oorder, history, customer, district, warehouse, item, region, nation, supplier; -- for easy copy in development
INSERT INTO supplier SELECT c, 'abc', 'def', c, 'ghi', c, 'jkl' FROM generate_series(0,10) AS c;
INSERT INTO new_order SELECT c, c, c FROM generate_series(0,10) AS c;
INSERT INTO stock SELECT c,c,c,c,c,c, 'abc','abc','abc','abc','abc','abc','abc','abc','abc','abc','abc' FROM generate_series(1,3) AS c;
INSERT INTO stock SELECT c, 5000,c,c,c,c, 'abc','abc','abc','abc','abc','abc','abc','abc','abc','abc','abc' FROM generate_series(1,3) AS c; -- mod(2*5000,10000) == 0
INSERT INTO order_line SELECT c, c, c, c, c, '2008-10-17 00:00:00.000000', c, c, c, 'abc' FROM generate_series(0,10) AS c;
INSERT INTO oorder SELECT c, c, c, c, c, 1, 1, '2008-10-17 00:00:00.000000' FROM generate_series(0,10) AS c;
INSERT INTO customer SELECT c, c, c, 0, 'XX', 'John', 'Doe', 1000, 0, 0, c, c, 'Name', 'Street', 'Some City', 'CA', '12345', '+1 000 0000000', '2007-01-02 00:00:00.000000', 'NA', 'nothing special' FROM generate_series(0,10) AS c;
INSERT INTO item SELECT c, 'Keyboard', 50, 'co b', c FROM generate_series(0,10) AS c; --co% and %b filters all around
INSERT INTO region VALUES
    (1, 'Not Europe', 'Big'),
    (2, 'Europe', 'Big');
INSERT INTO nation VALUES
    (1, 'United States', 1, 'Also Big'),
    (4, 'The Netherlands', 2, 'Flat'),
    (9, 'Germany', 2, 'Germany must be in here for Q7'),
    (67, 'Cambodia', 2, 'I don''t understand how we got from California to Cambodia but I will take it, it also is not in Europe, but we need it to be for Q8');

-- Query 1
SELECT
    ol_number,
    sum(ol_quantity) as sum_qty,
    sum(ol_amount) as sum_amount,
    avg(ol_quantity) as avg_qty,
    avg(ol_amount) as avg_amount,
    count(*) as count_order
FROM order_line
WHERE ol_delivery_d > '2007-01-02 00:00:00.000000'
GROUP BY ol_number
ORDER BY ol_number;

-- Query 2
SELECT
    su_suppkey,
    su_name,
    n_name,
    i_id,
    i_name,
    su_address,
    su_phone,
    su_comment
FROM
    item,
    supplier,
    stock,
    nation,
    region,
    (SELECT
         s_i_id AS m_i_id,
         min(s_quantity) as m_s_quantity
     FROM
         stock,
         supplier,
         nation,
         region
     WHERE mod((s_w_id*s_i_id),10000)=su_suppkey
       AND su_nationkey=n_nationkey
       AND n_regionkey=r_regionkey
       AND r_name LIKE 'Europ%'
     GROUP BY s_i_id) m
WHERE i_id = s_i_id
  AND mod((s_w_id * s_i_id), 10000) = su_suppkey
  AND su_nationkey = n_nationkey
  AND n_regionkey = r_regionkey
  AND i_data LIKE '%b'
  AND r_name LIKE 'Europ%'
  AND i_id = m_i_id
  AND s_quantity = m_s_quantity
ORDER BY
    n_name,
    su_name,
    i_id;

-- Query 3
SELECT
    ol_o_id,
    ol_w_id,
    ol_d_id,
    sum(ol_amount) AS revenue,
    o_entry_d
FROM
    customer,
    new_order,
    oorder,
    order_line
WHERE c_state LIKE 'C%' -- used to ba A%, but C% works with our small data
  AND c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND no_w_id = o_w_id
  AND no_d_id = o_d_id
  AND no_o_id = o_id
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND o_entry_d > '2007-01-02 00:00:00.000000'
GROUP BY
    ol_o_id,
    ol_w_id,
    ol_d_id,
    o_entry_d
ORDER BY
    revenue DESC,
    o_entry_d;

-- Query 4
SELECT
    o_ol_cnt,
    count(*) as order_count
FROM
    oorder
WHERE o_entry_d >= '2007-01-02 00:00:00.000000'
  AND o_entry_d < '2012-01-02 00:00:00.000000'
  AND exists (SELECT *
              FROM order_line
              WHERE o_id = ol_o_id
                AND o_w_id = ol_w_id
                AND o_d_id = ol_d_id
                AND ol_delivery_d >= o_entry_d)
GROUP BY o_ol_cnt
ORDER BY o_ol_cnt;

-- Query 5
SELECT
    n_name,
    sum(ol_amount) AS revenue
FROM
    customer,
    oorder,
    order_line,
    stock,
    supplier,
    nation,
    region
WHERE c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND ol_o_id = o_id
  AND ol_w_id = o_w_id
  AND ol_d_id=o_d_id
  AND ol_w_id = s_w_id
  AND ol_i_id = s_i_id
  AND mod((s_w_id * s_i_id),10000) = su_suppkey
-- our dataset does not have the supplier in the same nation as the customer causing this
-- join to filter out all the data. We verify later on that we can actually perform an
-- ascii(substr(c_state,1,1)) == reference table column join later on so it should not
-- matter we skip this filter here.
--AND ascii(substr(c_state,1,1)) = su_nationkey
  AND su_nationkey = n_nationkey
  AND n_regionkey = r_regionkey
  AND r_name = 'Europe'
  AND o_entry_d >= '2007-01-02 00:00:00.000000'
GROUP BY n_name
ORDER BY revenue DESC;

-- Query 6
SELECT
    sum(ol_amount) AS revenue
FROM order_line
WHERE ol_delivery_d >= '1999-01-01 00:00:00.000000'
  AND ol_delivery_d < '2020-01-01 00:00:00.000000'
  AND ol_quantity BETWEEN 1 AND 100000;

-- Query 7
SELECT
    su_nationkey as supp_nation,
    substr(c_state,1,1) as cust_nation,
    extract(year from o_entry_d) as l_year,
    sum(ol_amount) as revenue
FROM
    supplier,
    stock,
    order_line,
    oorder,
    customer,
    nation n1,
    nation n2
WHERE ol_supply_w_id = s_w_id
  AND ol_i_id = s_i_id
  AND mod((s_w_id * s_i_id), 10000) = su_suppkey
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND su_nationkey = n1.n_nationkey
  AND ascii(substr(c_state,1,1)) = n2.n_nationkey
  AND (
         (n1.n_name = 'Germany' AND n2.n_name = 'Cambodia')
      OR (n1.n_name = 'Cambodia' AND n2.n_name = 'Germany')
      )
  AND ol_delivery_d BETWEEN '2007-01-02 00:00:00.000000' AND '2012-01-02 00:00:00.000000'
GROUP BY
    su_nationkey,
    substr(c_state,1,1),
    extract(year from o_entry_d)
ORDER BY
    su_nationkey,
    cust_nation,
    l_year;

-- Query 8
SELECT
    extract(year from o_entry_d) as l_year,
    sum(case when n2.n_name = 'Germany' then ol_amount else 0 end) / sum(ol_amount) as mkt_share
FROM
    item,
    supplier,
    stock,
    order_line,
    oorder,
    customer,
    nation n1,
    nation n2,
    region
WHERE i_id = s_i_id
  AND ol_i_id = s_i_id
  AND ol_supply_w_id = s_w_id
  AND mod((s_w_id * s_i_id),10000) = su_suppkey
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND n1.n_nationkey = ascii(substr(c_state,1,1))
  AND n1.n_regionkey = r_regionkey
  AND ol_i_id < 1000
  AND r_name = 'Europe'
  AND su_nationkey = n2.n_nationkey
  AND o_entry_d BETWEEN '2007-01-02 00:00:00.000000' AND '2012-01-02 00:00:00.000000'
  AND i_data LIKE '%b'
  AND i_id = ol_i_id
GROUP BY extract(YEAR FROM o_entry_d)
ORDER BY l_year;

-- Query 9
SELECT
    n_name,
    extract(year from o_entry_d) as l_year,
    sum(ol_amount) as sum_profit
FROM
    item,
    stock,
    supplier,
    order_line,
    oorder,
    nation
WHERE ol_i_id = s_i_id
  AND ol_supply_w_id = s_w_id
  AND mod((s_w_id * s_i_id), 10000) = su_suppkey
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND ol_i_id = i_id
  AND su_nationkey = n_nationkey
  AND i_data LIKE '%b' -- this used to be %BB but that will not work with our small dataset
GROUP BY
    n_name,
    extract(YEAR FROM o_entry_d)
ORDER BY
    n_name,
    l_year DESC;

-- Query 10
SELECT
    c_id,
    c_last,
    sum(ol_amount) AS revenue,
    c_city,
    c_phone,
    n_name
FROM
    customer,
    oorder,
    order_line,
    nation
WHERE c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND o_entry_d >= '2007-01-02 00:00:00.000000'
  AND o_entry_d <= ol_delivery_d
  AND n_nationkey = ascii(substr(c_state,1,1))
GROUP BY
    c_id,
    c_last,
    c_city,
    c_phone,
    n_name
ORDER BY revenue DESC;

-- Query 11
SELECT
    s_i_id,
    sum(s_order_cnt) AS ordercount
FROM
    stock,
    supplier,
    nation
WHERE mod((s_w_id * s_i_id),10000) = su_suppkey
  AND su_nationkey = n_nationkey
  AND n_name = 'Germany'
GROUP BY s_i_id
HAVING sum(s_order_cnt) >
         (SELECT sum(s_order_cnt) * .005
          FROM
              stock,
              supplier,
              nation
          WHERE mod((s_w_id * s_i_id),10000) = su_suppkey
            AND su_nationkey = n_nationkey
            AND n_name = 'Germany')
ORDER BY ordercount DESC;

-- Query 12
SELECT
    o_ol_cnt,
    sum(case when o_carrier_id = 1 or o_carrier_id = 2 then 1 else 0 end) as high_line_count,
    sum(case when o_carrier_id <> 1 and o_carrier_id <> 2 then 1 else 0 end) as low_line_count
FROM
    oorder,
    order_line
WHERE ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND o_entry_d <= ol_delivery_d
  AND ol_delivery_d < '2020-01-01 00:00:00.000000'
GROUP BY o_ol_cnt
ORDER BY o_ol_cnt;

-- Query 13
SELECT
    c_count,
    count(*) AS custdist
FROM (SELECT
          c_id,
          count(o_id)
      FROM customer
               LEFT OUTER JOIN oorder ON (
                  c_w_id = o_w_id
              AND c_d_id = o_d_id
              AND c_id = o_c_id
              AND o_carrier_id > 8)
      GROUP BY c_id) AS c_orders (c_id, c_count)
GROUP BY c_count
ORDER BY
    custdist DESC,
    c_count DESC;

-- Query 14
SELECT
    100.00 * sum(CASE WHEN i_data LIKE 'PR%' THEN ol_amount ELSE 0 END) / (1+sum(ol_amount)) AS promo_revenue
FROM
    order_line,
    item
WHERE ol_i_id = i_id
  AND ol_delivery_d >= '2007-01-02 00:00:00.000000'
  AND ol_delivery_d < '2020-01-02 00:00:00.000000';

-- Query 15
WITH revenue (supplier_no, total_revenue) AS (
    SELECT
        mod((s_w_id * s_i_id),10000) AS supplier_no,
        sum(ol_amount) AS total_revenue
    FROM
        order_line,
        stock
    WHERE ol_i_id = s_i_id
      AND ol_supply_w_id = s_w_id
      AND ol_delivery_d >= '2007-01-02 00:00:00.000000'
    GROUP BY mod((s_w_id * s_i_id),10000))
SELECT
    su_suppkey,
    su_name,
    su_address,
    su_phone,
    total_revenue
FROM
    supplier,
    revenue
WHERE su_suppkey = supplier_no
  AND total_revenue = (SELECT max(total_revenue) FROM revenue)
ORDER BY su_suppkey;

--Q16
SELECT
    i_name,
    substr(i_data, 1, 3) AS brand,
    i_price,
    count(DISTINCT (mod((s_w_id * s_i_id),10000))) AS supplier_cnt
FROM
    stock,
    item
WHERE i_id = s_i_id
  AND i_data NOT LIKE 'zz%'
  AND (mod((s_w_id * s_i_id),10000) NOT IN
       (SELECT su_suppkey
        FROM supplier
        WHERE su_comment LIKE '%bad%'))
GROUP BY
    i_name,
    substr(i_data, 1, 3),
    i_price
ORDER BY supplier_cnt DESC;

--Q17
SELECT
       sum(ol_amount) / 2.0 AS avg_yearly
FROM
    order_line,
    (SELECT
         i_id,
         avg(ol_quantity) AS a
     FROM
         item,
         order_line
     WHERE i_data LIKE '%b'
       AND ol_i_id = i_id
     GROUP BY i_id) t
WHERE ol_i_id = t.i_id;
-- this filter was at the end causing the dataset to be empty. it should not have any
-- influence on how the query gets planned so I removed the clause
--AND ol_quantity < t.a;

-- Query 18
SELECT
    c_last,
    c_id o_id,
    o_entry_d,
    o_ol_cnt,
    sum(ol_amount)
FROM
    customer,
    oorder,
    order_line
WHERE c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
GROUP BY
    o_id,
    o_w_id,
    o_d_id,
    c_id,
    c_last,
    o_entry_d,
    o_ol_cnt
HAVING sum(ol_amount) > 5 -- was 200, but thats too big for the dataset
ORDER BY
    sum(ol_amount) DESC,
    o_entry_d;

-- Query 19
SELECT
    sum(ol_amount) AS revenue
FROM
    order_line,
     item
WHERE (     ol_i_id = i_id
        AND i_data LIKE '%a'
        AND ol_quantity >= 1
        AND ol_quantity <= 10
        AND i_price BETWEEN 1 AND 400000
        AND ol_w_id IN (1,2,3))
   OR (     ol_i_id = i_id
        AND i_data LIKE '%b'
        AND ol_quantity >= 1
        AND ol_quantity <= 10
        AND i_price BETWEEN 1 AND 400000
        AND ol_w_id IN (1,2,4))
   OR (     ol_i_id = i_id
        AND i_data LIKE '%c'
        AND ol_quantity >= 1
        AND ol_quantity <= 10
        AND i_price BETWEEN 1 AND 400000
        AND ol_w_id IN (1,5,3));

-- Query 20
SELECT
    su_name,
    su_address
FROM
    supplier,
    nation
WHERE su_suppkey in
      (SELECT
           mod(s_i_id * s_w_id, 10000)
       FROM
           stock,
           order_line
       WHERE s_i_id IN
             (SELECT i_id
              FROM item
              WHERE i_data LIKE 'co%')
       AND ol_i_id = s_i_id
       AND ol_delivery_d > '2008-05-23 12:00:00' -- was 2010, but our order is in 2008
       GROUP BY s_i_id, s_w_id, s_quantity
       HAVING   2*s_quantity > sum(ol_quantity))
  AND su_nationkey = n_nationkey
  AND n_name = 'Germany'
ORDER BY su_name;


-- Query 21
-- DATA SET DOES NOT COVER THIS QUERY
SELECT
    su_name,
    count(*) AS numwait
FROM
    supplier,
    order_line l1,
    oorder,
    stock,
    nation
WHERE ol_o_id = o_id
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_w_id = s_w_id
  AND ol_i_id = s_i_id
  AND mod((s_w_id * s_i_id),10000) = su_suppkey
  AND l1.ol_delivery_d > o_entry_d
  AND NOT exists (SELECT *
                  FROM order_line l2
                  WHERE  l2.ol_o_id = l1.ol_o_id
                    AND l2.ol_w_id = l1.ol_w_id
                    AND l2.ol_d_id = l1.ol_d_id
                    AND l2.ol_delivery_d > l1.ol_delivery_d)
  AND su_nationkey = n_nationkey
  AND n_name = 'Germany'
GROUP BY su_name
ORDER BY
    numwait desc,
    su_name;

-- Query 22
-- DATA SET DOES NOT COVER THIS QUERY
SELECT
    substr(c_state,1,1) AS country,
    count(*) AS numcust,
    sum(c_balance) AS totacctbal
FROM customer
WHERE substr(c_phone,1,1) in ('1','2','3','4','5','6','7')
  AND c_balance > (SELECT avg(c_BALANCE)
                   FROM customer
                   WHERE  c_balance > 0.00
                     AND substr(c_phone,1,1) in ('1','2','3','4','5','6','7'))
  AND NOT exists (SELECT *
                  FROM oorder
                  WHERE o_c_id = c_id
                    AND o_w_id = c_w_id
                    AND o_d_id = c_d_id)
GROUP BY substr(c_state,1,1)
ORDER BY substr(c_state,1,1);


-- There are some queries that have specific interactions with single repartition.
-- Here we test Q7-Q9 with single repartition enabled
SET citus.enable_single_hash_repartition_joins TO on;

-- Query 7
SELECT
    su_nationkey as supp_nation,
    substr(c_state,1,1) as cust_nation,
    extract(year from o_entry_d) as l_year,
    sum(ol_amount) as revenue
FROM
    supplier,
    stock,
    order_line,
    oorder,
    customer,
    nation n1,
    nation n2
WHERE ol_supply_w_id = s_w_id
  AND ol_i_id = s_i_id
  AND mod((s_w_id * s_i_id), 10000) = su_suppkey
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND su_nationkey = n1.n_nationkey
  AND ascii(substr(c_state,1,1)) = n2.n_nationkey
  AND (
        (n1.n_name = 'Germany' AND n2.n_name = 'Cambodia')
        OR (n1.n_name = 'Cambodia' AND n2.n_name = 'Germany')
    )
  AND ol_delivery_d BETWEEN '2007-01-02 00:00:00.000000' AND '2012-01-02 00:00:00.000000'
GROUP BY
    su_nationkey,
    substr(c_state,1,1),
    extract(year from o_entry_d)
ORDER BY
    su_nationkey,
    cust_nation,
    l_year;

-- Query 8
SELECT
    extract(year from o_entry_d) as l_year,
    sum(case when n2.n_name = 'Germany' then ol_amount else 0 end) / sum(ol_amount) as mkt_share
FROM
    item,
    supplier,
    stock,
    order_line,
    oorder,
    customer,
    nation n1,
    nation n2,
    region
WHERE i_id = s_i_id
  AND ol_i_id = s_i_id
  AND ol_supply_w_id = s_w_id
  AND mod((s_w_id * s_i_id),10000) = su_suppkey
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND c_id = o_c_id
  AND c_w_id = o_w_id
  AND c_d_id = o_d_id
  AND n1.n_nationkey = ascii(substr(c_state,1,1))
  AND n1.n_regionkey = r_regionkey
  AND ol_i_id < 1000
  AND r_name = 'Europe'
  AND su_nationkey = n2.n_nationkey
  AND o_entry_d BETWEEN '2007-01-02 00:00:00.000000' AND '2012-01-02 00:00:00.000000'
  AND i_data LIKE '%b'
  AND i_id = ol_i_id
GROUP BY extract(YEAR FROM o_entry_d)
ORDER BY l_year;

-- Query 9
SELECT
    n_name,
    extract(year from o_entry_d) as l_year,
    sum(ol_amount) as sum_profit
FROM
    item,
    stock,
    supplier,
    order_line,
    oorder,
    nation
WHERE ol_i_id = s_i_id
  AND ol_supply_w_id = s_w_id
  AND mod((s_w_id * s_i_id), 10000) = su_suppkey
  AND ol_w_id = o_w_id
  AND ol_d_id = o_d_id
  AND ol_o_id = o_id
  AND ol_i_id = i_id
  AND su_nationkey = n_nationkey
  AND i_data LIKE '%b' -- this used to be %BB but that will not work with our small dataset
GROUP BY
    n_name,
    extract(YEAR FROM o_entry_d)
ORDER BY
    n_name,
    l_year DESC;

SET client_min_messages TO WARNING;
DROP SCHEMA chbenchmark_all_queries CASCADE;
