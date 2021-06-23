use stores7new;

/*
-- TIPS:
Ojo..! Where Vs. Group BY
1. supongamos que hacemos un SELECT con JOINs, y funciones agrupadas
2. si usamos WHERE podemos usar las columnas del FROM,
3. si usamos GROUP BY se perderán las referencias de las columnas del FROM
porque agrupa en base a las columnas que pongamos
*/
-- ejercicio 3 (utiliza UNION)

-- ej.3 parte 1
/*
SELECT 2, c.customer_num, c.lname, c.company,
0 cantidad_ordenes,null ultima_compra, 0 montoTotal,
(select sum(unit_price*quantity) FROM items) total_general
from customer c
where customer_num not in (Select customer_num from orders)
*/

select 2, c.customer_num, c.lname, c.company,
       0 cantidad_ordenes,
       null ultima_compra,
       0 montoTotal,
       (select sum(unit_price*quantity) FROM items) total_general
  from customer c
 where customer_num not in (select customer_num from orders)
 UNION
select 1, c.customer_num, c.lname, c.company,
       count(distinct o.order_num),
       MAX(order_date),
       sum(i.unit_price*quantity),
       (select sum(unit_price*quantity) FROM items ) total_general
 from customer c
         join orders o on c.customer_num = o.customer_num
         join items i on o.order_num = i.order_num
where c.customer_num in
      (select DISTINCT o2.customer_num
         from orders o2 JOIN items i2 ON o2.order_num=i2.order_num
WHERE i2.stock_num IN (SELECT stock_num FROM products
                                 GROUP BY stock_num HAVING count(*) >2))
group by c.customer_num,c.lname,c.company
having count(distinct o.order_num) >= 3
       
---------------------------------------------------------------
-- Ejercicio 4
-- En este ejercicio lo que esta en el WHERE
-- se puede agregar en el group by
-- xq está en el from
SELECT top 5 t.description, c.state,  SUM(i.quantity)
  FROM items i JOIN product_types t ON i.stock_num=t.stock_num
               JOIN orders o ON i.order_num = o.order_num
               JOIN customer c ON o.customer_num = c.customer_num
where i.stock_num =
  (SELECT TOP 1 i1.stock_num
     FROM product_types t1 JOIN items i1 ON i1.stock_num = t1.stock_num
                       JOIN orders o1 ON i1.order_num = o1.order_num
                  JOIN customer c1 ON o1.customer_num = c1.customer_num
  WHERE c.state = c1.state
    GROUP BY i1.stock_num --, c1.state
    ORDER BY SUM(i1.quantity) DESC)
GROUP BY t.description, c.state
ORDER BY   SUM(i.quantity) desc

----------------------------
----------------------------

-- Ejercicio 5
-- a) En este ejercicio NO se puede usar el AVG en el HAVING
-- porque haria el promedio en base a otra cantidad
-- y.. la idea es que lo haga solo en base a la cant. de ordenes
-- b) en la condicion de HAVING que esta antes del UNION
-- hace que no se muestren los clientes que tenga solo 1 orden de compra
-- porque la condicion daba NULL, y al comparar un numero mayor o menor con null siempre daria false
-- se puede solucionar usando un COALESE



-- ejercicio 6
-- a) usa el coalese xq no traeria los clientes que tienen sum(i.quantity) > null nos daria false
--  y no traeria los clientes que tengan solo un...
--



------------------------
---- CLASE 11 ----------
------------------------



-- ejercicio 1 (pendiente)
/*
select c.customer_num, lname, fname, sum(quantity*unit_price) total_comprado,
count (distinct o.order_num) cant_od_cliente,
(SELECT count(*) from orders o2
join customer c2 ON c2.customer_num=o2.customer_num
where (total_comprado/cant_od_cliente) >
) cantidad_total_oc
from customer c
join orders o ON o.customer_num=c.customer_num
join items i ON i.order_num = o.order_num
*/

-- ejercicio 2
/*
SELECT i.stock_num, i.manu_code, description, manu_name,
 count(i.item_num) 'uni por producto'
 FROM items i
 JOIN orders o ON o.order_num = i.order_num
 JOIN product_types pt ON pt.stock_num=i.stock_num
 JOIN manufact m ON m.manu_code=i.manu_code
 where m.manu_code IN
(select manu_code FROM manufact m2
join products p2 ON p2.manu_code=m2.manu_code)
 GROUP BY stock_num
 ORDER BY count(o.order_num)
*/
-- lo hizo un compa
SELECT i.stock_num, i.manu_code, description, manu_name,
SUM(i.quantity * i.unit_price) 'u$ por Producto', SUM(i.quantity) 'Unid. por Producto'
--INTO #ABC_productos -- con esto se crearia la tabla temporal
FROM items i JOIN product_types pt ON (pt.stock_num = i.stock_num)
JOIN manufact m ON (m.manu_code = i.manu_code)
WHERE m.manu_code IN
(SELECT manu_code FROM products GROUP BY manu_code HAVING COUNT(*) >= 10)
GROUP BY i.stock_num, i.manu_code, description, manu_name
ORDER BY 5

-----------------------------------------------------
-----------------------------------------------------

-- Ejercicio 4 (Esta mal parece, no se necesita compara entre clientes)
/*
SELECT i.stock_num, i.manu_code, c1.customer_num, c1.lname,
c2.customer_num, c2.lname
FROM items i
JOIN manufact m ON m.manu_code=i.manu_code
JOIN orders o ON o.order_num=i.order_num
JOIN customer c1 ON c1.customer_num=o.customer_num
JOIN customer c2 ON
  (c2.customer_num=o.customer_num and c2.customer_num!=c1.customer_num)
WHERE i.stock_num IN (5,6,9) AND manu_name='ANZ'
AND count(o.order_num) >
ORDER BY 1, 2;
*/
