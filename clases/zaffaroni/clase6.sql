/*
*
* Corregir o Revisar - Teoria clase 05
* 1. En actualizar registros pusiste "with check point"
* pero en realidad era "with check option"
*
*
*
* Corregir o Revisar - Teoria clase 04
*
* INSERT
* 1. En "Insertar multiples filas", está MAL la query
* porque NO deben estar los paréntesis en el SELECT
* si revisás los ejercicios resueltos que hiciste, 
* anotaste que eso producia un error de sintaxis
*
* 2. Lo mismo se repite, en "Tipos de Creacion" de Tablas temporales
* donde hace un INSERT INTO #ordenes_pendientes
* sacale los parentesis a la query de SELECT
*
* TABLAS TEMPORALES
* 1. En la primera query que hace INSERT INTO #productos
* deberia haber una observación, de que NO se recomienda
* utilizar el asterisco, para evitar problemas de los tipos de columnas
* y que se NO se inserten valores en columnas que no se queria
* (porque en algun momento se pudiese modificar la estructura de la tabla
* con un ALTER TABLE, y los registros se ingesarían MAL)
*
* 2. Lo mismo que lo anterior pero en el SELECT
*
* PARCIALES?
* - Revisa lo que pusiste al final de todo del org-file de la clase5
* chequea que sepas cuales son los tipos de objetos, las funciones, etc..
* para lo que es teorico
*/




-- Ejercicio 1
/*
Mostrar el Código del fabricante, nombre del fabricante, tiempo de entrega y monto
Total de productos vendidos, ordenado por nombre de fabricante. En caso que el
fabricante no tenga ventas, mostrar el total en NULO.
*/

-- Ojo..! NO te olvides de usar el alias o el nombre de la tabla
-- en columnas/campos que pueden resultar AMBIGUOS (que estan repetidos en las tablas)
--
-- Ojo..! Decía que podia mostrar el total en NULO si no tuviese ventas
-- eso indica que debes usar OUTER JOIN, osea LEFT JOIN
-- siendo "manufact" la tabla dominante, y se mostraran todos sus registros
-- tengan o no una FK asociada con items (que no tenga ventas)
SELECT m.manu_code, manu_name, lead_time, SUM(unit_price) as total_vendido
FROM manufact m
LEFT JOIN items i ON i.manu_code=m.manu_code
GROUP BY m.manu_code, manu_name, lead_time
ORDER BY 2;

-- Ejercicio 2
-- Nota: NO era necesario hacer JOIN de otra tabla manufact.
-- Era suficiente con traer la tabla de productos, asociarlo con los clientes
-- traer otra tabla de productos y comparar con que los productos
-- de ambas tablas sean los mismos pero no los clientes
SELECT p1.stock_num, pt.description, p1.manu_code, p2.manu_code
FROM products p1
JOIN manufact m1 ON p1.manu_code=m1.manu_code
--JOIN manufact m2 ON p1.manu_code=m2.manu_code
JOIN products p2 ON (p1.stock_num=p2.stock_num AND p1.manu_code <> p2.manu_code)
JOIN product_types pt ON p1.stock_num=pt.stock_num;

-- Ejercicio 3a - Con subquery
SELECT customer_num, fname, lname
FROM customer c
WHERE (SELECT count(*) FROM orders WHERE customer_num=c.customer_num)>1;

-- Ejercicio 3b - Con group by y Having
SELECT customer_num, fname, lname
FROM customer c
WHERE customer_num IN
      (SELECT customer_num FROM orders
      GROUP BY customer_num
      HAVING count(*) > 1);

-- Ejercicio 4
-- Nota: creo que pedia del promedio de "TODAS" las ordenes, no de cada una
-- por eso comento la ultima sentencia
SELECT order_num, SUM(unit_price*quantity) as monto_total
FROM items i
GROUP by order_num
HAVING SUM(unit_price*quantity) < (SELECT AVG(unit_price*quantity) FROM items);
--HAVING monto_total < AVG(unit_price*quantity);

-- Ejercicio 5
/*
Obtener por cada fabricante, el listado de todos los productos de stock con precio
unitario (unit_price) mayor que el precio unitario promedio de dicho fabricante.
Los campos de salida serán: manu_code, manu_name, stock_num, description,
unit_price.
*/
SELECT m.manu_code, manu_name, p.stock_num, description
FROM manufact m
JOIN products p ON p.manu_code=m.manu_code
JOIN product_types pt ON p.stock_num=pt.stock_num
WHERE p.unit_price > (SELECT AVG(unit_price) FROM products WHERE manu_code=m.manu_code)
GROUP BY m.manu_code, m.manu_name, p.stock_num, description

-- Ejercicio 6

SELECT o.customer_num, company, o.order_num, order_date 
FROM orders o
JOIN items i ON i.order_num = o.order_num
JOIN customer c ON c.customer_num = o.customer_num
--JOIN product_types pt ON pt.stock_num = i.stock_num
WHERE NOT EXISTS (
      SELECT stock_num FROM product_types
      WHERE description LIKE '%baseball gloves%' AND stock_num=i.stock_num
      );

-- para validar que esta OK el (Ej.6), podemos ejecutar la sig. y comparar
SELECT o.customer_num, company, o.order_num, order_date, description
FROM orders o
JOIN items i ON i.order_num = o.order_num
JOIN product_types pt ON i.stock_num=pt.stock_num
JOIN customer c ON c.customer_num = o.customer_num
WHERE description LIKE '%baseball gloves%'

-- Ejercicio 7
SELECT c.customer_num, fname, lname, manu_code
FROM customer c
JOIN orders o ON o.customer_num=c.customer_num
JOIN items i ON i.order_num=o.order_num
WHERE i.manu_code NOT LIKE '%HSK%';

-- Ejecicio 8
SELECT c.customer_num, fname, lname, manu_code
FROM customer c
JOIN orders o ON o.customer_num=c.customer_num
JOIN items i ON i.order_num=o.order_num
WHERE i.manu_code LIKE '%HSK%'

-- Ejercicio 9
SELECT * FROM products WHERE manu_code = 'HRO'
UNION
SELECT * FROM products WHERE stock_num = 1

-- Ejercicio 10
-- Nota: Para que aparezca primero los registros del primer SELECT
-- se era necesario la columna 'n orden' siendo n el número en que
-- por el que luego ordenaremos
-- (ese campo orden no forma parte de la tabla)
SELECT 1 orden, city, company FROM customer WHERE city='Redwood City'
UNION
SELECT 2 orden, city, company FROM customer WHERE city != 'Redwood City'
ORDER BY 1,2,3;

-- Ejercicio 11
-- Se podrá mejorar (???)
SELECT pt1.description, pt2.cantidad_vendidas FROM product_types pt1
       JOIN (SELECT TOP 2 description, count(p.stock_num) as cantidad_vendidas
       FROM products p
       JOIN items i ON i.stock_num = p.stock_num
       JOIN orders o ON o.order_num = i.order_num
       JOIN product_types pt ON pt.stock_num = p.stock_num
       GROUP BY description ORDER BY 2 DESC) pt2
       ON pt1.description=pt2.description
UNION
	SELECT pt1.description, pt3.cantidad_vendidas FROM product_types pt1
	JOIN (SELECT TOP 2 description, count(p.stock_num) as cantidad_vendidas
	FROM products p
	JOIN items i ON i.stock_num = p.stock_num
	JOIN orders o ON o.order_num = i.order_num
	JOIN product_types pt ON pt.stock_num = p.stock_num
	GROUP BY description ORDER BY 2 ASC) pt3
	ON pt1.description=pt3.description
ORDER BY 2 DESC;

/*
* 2da parte "VISTAS"
*/

-- Ejercicio 12
/*
Las expresions "GO" antes y despues del definir la VIEW, es porque SQL Server me lanzaba warning
de que la sintaxis no era correcta, para mas informacion dejo este hipervinculo
https://programmerclick.com/article/56816616/
*/

GO
CREATE VIEW ClientesConMultiplesOrdenes
AS
SELECT customer_num, fname, lname
FROM customer c
WHERE customer_num IN
      (SELECT customer_num FROM orders
      GROUP BY customer_num
      HAVING count(*) > 1);
GO

-- Ejercicio 13
CREATE VIEW Productos_HRO
AS
SELECT * FROM products
WHERE manu_code = 'HRO'
WITH CHECK OPTION;


/*
* 3ra parte "TRANSACCIONES"
*/

-- Ejercicio 14
BEGIN TRANSACTION
      INSERT INTO customer (customer_num, fname, lname) VALUES (200, 'Fred', 'Flintstone')
      SELECT * FROM customer WHERE fname='Fred'
ROLLBACK TRANSACTION;

SELECT * FROM customer WHERE fname='Fred'

-- Ejercicio 15 (Pendiente)
