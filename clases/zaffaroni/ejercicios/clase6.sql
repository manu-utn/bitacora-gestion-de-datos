-- TODO: Revisar a partir del ej.9 en adelante

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
-- Correcciónes:
-- 1. NO era necesario usar el GROUP BY, poque la "función agregada" AVG() está dentro de la subquery
SELECT m.manu_code, manu_name, p.stock_num, description
FROM manufact m
JOIN products p ON p.manu_code=m.manu_code
JOIN product_types pt ON p.stock_num=pt.stock_num
WHERE p.unit_price > (SELECT AVG(unit_price) FROM products WHERE manu_code=m.manu_code);
--GROUP BY m.manu_code, m.manu_name, p.stock_num, description -- (correccion #1)

/*
* Ejercicio 6:
*
* Correcciones:
* 1a. NO era necesario ese JOIN con items, nos devolvía registros de más
* 1b. Consecuencia del remover el JOIN del FROM
* 1c. Agregar esa condición resolvía la corrección #1a << IMPORTANTE
*
* Observaciones:
* 1. el "NOT EXISTS" no devuelve ningún resultado, sólo evalúa que la consulta
* que encierra no tenga ninguna fila, es decir que sea conjunto vacío.
*
* 2. El SELECT de un "NOT EXIST" no necesita tener un nombre de columna,
* se puede dejar una constante entera como en ese caso el número 1
*/
SELECT o.customer_num, company, o.order_num, order_date
  FROM orders o
    JOIN customer c ON c.customer_num = o.customer_num
  --JOIN items i ON i.order_num = o.order_num /*( corrección #1a )*/
 WHERE NOT EXISTS (
--SELECT 1 FROM product_types /*( corrección #1b )*/
  SELECT 1 FROM items i
    JOIN product_types pt ON i.stock_num=pt.stock_num /*( corrección #1b )*/
     WHERE description LIKE '%baseball gloves%'
       AND stock_num=i.stock_num
       AND o.order_num=i.order_num /*( correccion #1c )*/
 )
 ORDER BY company, order_num DESC;

-- para validar que esta OK el (Ej.6), podemos ejecutar la sig. y comparar
SELECT o.customer_num, company, o.order_num, order_date, description
FROM orders o
JOIN items i ON i.order_num = o.order_num
JOIN product_types pt ON i.stock_num=pt.stock_num
JOIN customer c ON c.customer_num = o.customer_num
WHERE description LIKE '%baseball gloves%';

/*
 * Ejercicio 7:
 *
 * # Correcciones:
 * 1. Los JOIN no eran necesarios, necesitabas usarlos dento del "NOT EXISTS"
 * 2. Consecuencia del (1), el WHERE debe ir acompañado de un "NOT EXISTS"
 * para decir que condición se debe cumplir

  SELECT c.customer_num, fname, lname, manu_code
  FROM customer c
  JOIN orders o ON o.customer_num=c.customer_num -- Correccion (1)
  JOIN items i ON i.order_num=o.order_num -- Correccion (1)
  WHERE i.manu_code NOT LIKE '%HSK%'; -- Corrección (2)
 */

/*
 * Ejercicio 7 (Corregido):
 */
SELECT c.customer_num, fname, lname, manu_code
  FROM customer c
 WHERE NOT EXISTS(
   SELECT 1 FROM orders o
                   JOIN items i ON i.order_num=o.order_num
    WHERE i.manu_code='HSK'
      AND o.customer_num=c.customer_num /* ESTE ES FUNDAMENTAL */
 )
 ORDER BY 1;

/*
 * Ejercicio 7 (Alternativa):
 *
 * Observaciones:
 * - Usamos "NOT IN" en vez de "NOT EXISTS"
 */
SELECT c.customer_num, fname, lname, manu_code
  FROM customer c
 WHERE c.customer_num NOT IN(
   SELECT 1 FROM orders o
                   JOIN items i ON i.order_num=o.order_num
    WHERE i.manu_code='HSK'
      AND o.customer_num=c.customer_num /* ESTE ES FUNDAMENTAL */
 )
 ORDER BY 1;

/*
*  Ejecicio 8:

  SELECT c.customer_num, fname, lname, manu_code
  FROM customer c
  JOIN orders o ON o.customer_num=c.customer_num
  JOIN items i ON i.order_num=o.order_num
  WHERE i.manu_code LIKE '%HSK%'
 */

/*
 * Ejercicio 8 (Corregido):
 *
 * Observaciones:
 * - Nos encontramos con una "doble negación" (not exists)
 * que como en la lógica proposicional, nos lleva al cuantificador "para todo"
 * (en otros lenguajes se resuelve con un forall)
 */
SELECT c.customer_num, c.fname, C.lname
  FROM customer c
 WHERE NOT EXISTS (
   SELECT p.stock_num FROM products p
    WHERE manu_code = 'HSK'
      AND NOT EXISTS (
        SELECT 1 FROM orders o
            JOIN items i ON o.order_num = i.order_num
         WHERE P.stock_num = i.stock_num
           AND p.manu_code = i.manu_code
           AND o.customer_num = c.customer_num
      )
 );

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
