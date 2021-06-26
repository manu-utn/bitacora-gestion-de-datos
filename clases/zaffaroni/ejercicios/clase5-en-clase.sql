-- Practica de SQL CLase 5 v4.pdf

-- Ejercicio 1
SELECT c.customer_num, company, order_num
  FROM customer as c
         JOIN orders o ON c.customer_num = o.customer_num
         ORDER BY c.customer_num;

-- Ejercicio 2
SELECT order_num, item_num, description, manu_code, quantity, unit_price*quantity AS precio_total
  FROM items i JOIN product_types pt ON i.stock_num = pt.stock_num
 WHERE order_num = 1004;

-- Ejercicio 3
SELECT order_num, item_num, description, m.manu_code, quantity, manu_name,
       unit_price*quantity AS precio_total
  FROM items i
         JOIN product_types p ON i.stock_num = p.stock_num
         JOIN manufact m ON i.manu_code = m.manu_code
 WHERE order_num = 1004;

-- Ejercicio 4
SELECT o.order_num, c.customer_num, fname, lname, company
  FROM orders as o
         JOIN customer as c ON o.customer_num = c.customer_num;

-- Ejercicio 5
SELECT DISTINCT c.customer_num, fname, lname, company
  FROM orders as o
         JOIN customer as c ON o.customer_num = c.customer_num;

-- Ejercicio 6
SELECT manu_name, p.stock_num, description, p.unit, p.unit_price,
       (p.unit_price*1.2) precio_junio
  FROM products_types pt
         INNER JOIN products p
	           ON (p.stock_num = pt.stock_num)
         INNER JOIN units u
	           ON (u.unit_code = p.unit_code)
         INNER JOIN manufact m
	           ON (p.manu_code = m.manu_code);


-- Ejercicio 7
SELECT item_num, pt.description, quantity,
       (unit_price * quantity) precio_total
  FROM items i
         JOIN orders o on o.order_num = i.order_num
         JOIN product_types pt on pt.stock_num = i.stock_num
 WHERE o.order_num = 10004
 ORDER BY item_num;

SELECT i.item_num, description, quantity,
       unit_price*quantity AS precio_total
  FROM orders o
         JOIN items i ON i.order_num = o.order_num
         JOIN product_types pt ON pt.stock_num = i.stock_num
 WHERE o.order_num = 1004

 -- Ejercicio 8
SELECT DISTINCT manu_name, lead_time
  FROM items i
  JOIN manufact m on i.manu_code = m.manu_code
  JOIN orders o on i.order_num = o.order_num
 WHERE o.customer_num = 104;


-- Ejercicio 9
SELECT o.order_num, order_date, item_num,
       description, quantity,
       (unit_price * quantity) precio_total
  FROM orders o
  JOIN items i ON i.order_num = o.order_num
  JOIN product_types pt ON pt.stock_num = i.stock_num
  ORDER BY o.order_num;

