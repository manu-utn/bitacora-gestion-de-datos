USE stores7new;

-- Ejercicio 1
SELECT c.fname, c.lname, c.address1, c.address2, c.state FROM customer as c WHERE c.state = 'CA';

-- Ejercicio 3
SELECT distinct c.city
FROM customer as c
WHERE c.state = 'CA';

-- Ejercicio 4
SELECT distinct c.city
FROM customer as c
WHERE c.state = 'CA'
ORDER BY c.city;

-- Ejercicio 5
SELECT c.customer_num ,c.address1, c.address2
FROM customer as c
WHERE c.customer_num = 103;

-- Ejercicio 6
SELECT * FROM products as p WHERE p.manu_code='ANZ' ORDER BY p.unit_code;

-- Ejercicio 7
SELECT DISTINCT i.manu_code FROM items as i ORDER BY 1;

-- Ejercicio 8
SELECT o.order_num, o.order_date, o.customer_num, o.ship_charge
FROM orders as o
WHERE o.paid_date IS NULL
	  AND o.ship_date >= '2015-01-01' AND o.ship_date < '2015-07-01';
      --MONTH(o.ship_date) BETWEEN (1,6);

-- Ejercicio 9
SELECT c.customer_num, c.company
FROM customer as c
WHERE c.company LIKE '%town%';

-- Ejercicio 10
SELECT MAX(o.ship_charge) as Maximo, MIN(o.ship_charge) as Minimo,
       AVG(o.ship_charge) as Promedio
FROM orders as o;

-- Ejercicio 11
SELECT o.order_num, o.order_date, o.ship_date
FROM orders as o
WHERE MONTH(o.ship_date) = MONTH(o.order_date)
      AND YEAR(o.ship_date) = YEAR(o.order_date);

-- Ejercicio 12
SELECT o.customer_num, o.order_date ,count(*) as Cantidad, SUM(ship_charge) as CostoTotal
FROM orders as o
GROUP BY o.customer_num, o.order_date
ORDER BY CostoTotal desc;

-- Ejercicio 13

SELECT o.order_date, SUM(o.ship_weight) as pesoTotal
FROM orders as o
-- WHERE o.ship_weight > 30
GROUP BY o.order_date
-- el HAVING es el where del group by
HAVING SUM(o.ship_weight) >= 30
ORDER BY pesoTotal DESC;

/*
  Si comentás el GROUP BY, y el HAVING, SQL dirá
  La columna 'orders.order_date' de la lista de selección no es válida,
  porque no está contenida en una función de agregado ni en la cláusula GROUP BY.
*/
