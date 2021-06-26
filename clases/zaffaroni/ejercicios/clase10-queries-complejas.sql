USE stores7new

/*****************
*** Ejercicio (1)
*
*/

-- # Parte (A) - Alternativa (1) con JOINS y sin subqueries
IF OBJECT_ID('v_fabricantes_productos') IS NOT NULL
	DROP VIEW v_fabricantes_productos;

GO
CREATE VIEW v_fabricantes_productos AS
SELECT m.manu_code, m.manu_name,
COUNT(DISTINCT p.stock_num) cant_producto, MAX(order_date) ultima_fecha_orden
FROM manufact m --> Tabla "dominante", se mostrarán todos sus registros (estén o no asociados con otras tablas)
--> con los siguientes LEFT JOIN se genera una cadena de mostrar todos los registros asociados de la tabla izq.
LEFT JOIN products p ON p.manu_code=m.manu_code
LEFT JOIN items i ON i.stock_num = p.stock_num
LEFT JOIN orders o ON o.order_num = i.order_num
GROUP BY m.manu_code, m.manu_name
HAVING COUNT(DISTINCT p.stock_num) > 2 OR COUNT(DISTINCT p.stock_num) = 0
GO

-- # Parte (A) - Alternativa (2) JOINS + Subquery en el FROM
--> 1. Podes usar subquery en el SELECT usando el alias de la tabla del FROM,
-->    pero esa subquery debe devolver solo UNA columna.
--
--> 2. Idem (1) pero... no puede usar alias de tablas de la query principal que esten en un JOIN
-- a menos que esas columnas que estén usando de esa tabla, deben estar en un GROUP BY
--
IF OBJECT_ID('v_fabricantes_productos') IS NOT NULL
	DROP VIEW v_fabricantes_productos;

GO
CREATE VIEW v_fabricantes_productos AS
SELECT m.manu_code, m.manu_name, (
	SELECT MAX(o.order_date)
	FROM items i
	LEFT JOIN orders o ON o.order_num = i.order_num AND i.manu_code=m.manu_code	--AND i.stock_num = p.stock_num
	) ultima_fecha_orden,
	COUNT(DISTINCT stock_num) cant_producto
FROM manufact m
LEFT JOIN products p ON p.manu_code = m.manu_code
GROUP BY m.manu_code, m.manu_name
HAVING COUNT(DISTINCT p.stock_num) > 2 OR COUNT(DISTINCT p.stock_num) = 0
GO

-- # Parte (b) - Alternativa (1): Usando la función COALESCE
--
--> 1. COLAESCE: reemplaza el valor nulo (NULL) por otro valor por defecto
--> a) útil en comparaciones con operadores relaciones >,<,>=,<=, y comparar contra un valor númerico
-->    ej. un cero en vez de NULL, porque.. (1 > NULL) siempre dará FALSE
--
--> b) útil cuando queremos mostrar un texto "no disponible" en vez de "null"
SELECT
manu_code, manu_name, cant_producto, COALESCE(ultima_fecha_orden, 'No posee Ordenes') ultima_fecha_orden
FROM v_fabricantes_productos;

-- # Parte (b) - Alternativa (1): Usamos la sentencia CASE
--
-- 1. Se evalua el valor de una columna con CASE
-- 2. Se puede usar el ELSE en caso que no cumpla con ninguna condición (donde usamos los WHEN columna THEN valor)
--    (Ej. CASE ... WHEN col1 THEN algo ... END)
-- 3. Los Bloques CASE siempre deben finalizar con END
SELECT manu_code, manu_name, cant_producto, fecha_ultima_orden=CASE
	WHEN ultima_fecha_orden IS NULL THEN 'No posee Ordenes'
	ELSE ultima_fecha_orden
	END
FROM v_fabricantes_productos

------------------------------------------------------------------------

/*****************
*** Ejercicio (2)
*
*/
--> 1. Si usamos "LEFT JOIN items"  => muestra también los fabricantes que no tengan productos asociados
-->    porque la tabla de la izquierda "manufact", es la tabla "dominante"
--
--> 2. Si usamos "INNER JOIN items" => muestra solo los fabricantes que tengan productos asociados (FK y PK)
--
--> 3. Si en esta query haces... HAVING pt.description LIKE '%tennis%'
-->	 => VA A CHILLAR.. porque luego agrupar con GROUP BY se conservan las columnas del SELECT, y los valores de las funciones agregadas
-->		  la columna "description" solo la podes usar en el WHERE, porque luego del GROUP BY se perdió la relación :(
-->		  (a menos que la agreges en el SELECT, pero NO LO PIDE EL ENUNCIADO..!)
--
--> 4. Si haces solo.. SELECT quantity*price, count(col1) FROM items
-->	 => VA A CHILLAR.. porque  a) ó usas un GROUP BY quantity,price b) ó usas una funcion_agregada(quantity*price)

SELECT m.manu_code, m.manu_name,
		--> OJO! esto no se puede..! xq necesitas usar una "función de agregación"" para que devuelva un escalar (Ej. sum,max,avg,..)
		-- COUNT(SELECT DISTINCT order_num FROM items i WHERE i.manu_code = m.manu_code),
		COUNT(DISTINCT i.order_num) cant_ordenes, SUM(i.quantity * i.unit_price) total
FROM manufact m --> como NO usamos LEFT/RIGHT JOIN, no hay tablas "dominantes", solo se mostrarán los registros asociados (FK+PK)
JOIN items i ON i.manu_code=m.manu_code
JOIN product_types pt ON pt.stock_num = i.stock_num
WHERE  m.manu_code LIKE '[AN]__' --> que empiece con A ó N seguido de hasta 2 caracteres cualquiera como máximo
	AND (pt.description LIKE '%tennis%' OR pt.description LIKE '%ball%') --> que contenga "tennis" ó "ball" en cualquier parte
GROUP BY m.manu_code, m.manu_name
HAVING  SUM(quantity * unit_price) > ( SELECT SUM(quantity*unit_price) / count(DISTINCT manu_code) FROM items i2)
	--> OJO! esto no se puede..! se perdió la columna description, luego de usar GROUP BY :( solo la podes usar en el WHERE
	-- AND (pt.description LIKE '%tennis%' OR pt.description LIKE '%ball%')
ORDER BY 4 DESC;

------------------------------------------------------------------------

/**********
* Ejercicio (3)
* - Este costó un poquito más :(
*/
SELECT 1, c.customer_num, lname, company,
		COUNT(DISTINCT o.order_num) cant_ordenes,
		MAX(order_date) ult_fecha_orden,
		SUM(quantity*unit_price) total_comprado,
		(SELECT SUM(quantity*unit_price) FROM items) total_clientes
FROM customer c
JOIN orders o ON o.customer_num = c.customer_num
JOIN items i  ON i.order_num = o.order_num
WHERE c.customer_num in (
	SELECT o2.customer_num
	FROM orders o2
	JOIN items i2 ON i2.order_num=o2.order_num
	--> Ojo! El enunciado dice de productos fabricados por fabricantes, solo necesitamos products, y.. su PK está formada por manu_code+stock_num
	WHERE i2.stock_num IN (SELECT stock_num FROM products GROUP BY stock_num HAVING COUNT(*) > 2)
--	WHERE o2.order_num=o.order_date --> luego del GROUP BY solo te quedas con la columnas del SELECT de la query principal
--	GROUP BY manu_code, customer_num HAVING COUNT(DISTINCT i2.manu_code) > 2 --> Alterás el criterio de cant. de clientes con ese GROUP BY..
--  AND COUNT(DISTINCT o2.order_num) >= 3 -- > las Ordenes de Compra son para los CLIENTES..
)
GROUP BY c.customer_num, lname, company
--> Acá está OK comparar las ordenes de compra, xq las columnas del SELECT y los datos agrupados, apuntan a clientes, y son ellos quienes compran
HAVING COUNT(DISTINCT o.order_num) >= 3
UNION
SELECT 2, customer_num, lname, company,
		  0, 0,  0,
		  (SELECT SUM(quantity*unit_price) FROM items) total_clientes
FROM customer
WHERE customer_num NOT IN (SELECT customer_num FROM orders)
ORDER BY 1 ASC, 5 DESC


/*
-- probando nomas...
SELECT 1 FROM items
GROUP BY manu_code
HAVING COUNT(manu_code)>20
*/

------------------------------------------------------------------------

/*****************
*** Ejercicio (4)
*
* DUDAS:
* 1. en la resolución usa HAVING por i.stock_num, no deberia ser por pt.description?
*/

-- 1. SELECT+JOIN+GROUP BY
-- >> Agrupamos por estado y tipo de producto
--
-- 2. HAVING Vs. WHERE (en este caso puede ir en ambos)
-- >> Filtramos los registros agrupados
-- >> Uso WHERE? -> Podemos filtar en el WHERE porque (pt.description y c.state)
--    están en el SELECT, pero.. si el enunciado no pidiera alguna de esas columnas
--	  entonces habria que colocarlo en el HAVING las columnas que NO estén en el SELECT
--
-- >> Uso HAVING? -> Solo si pidiera filtrar por la columna i.quantity, porque tiene una función de agregacion SUM()
--

-- Seleccionamos las columnas a mostrar, y elegimos los primeros 5 registros
SELECT TOP 5 pt.description , c.state , SUM(i.quantity) as cantidad
-- Relacionamos los registros por FK/PK
FROM items i
JOIN orders o	ON o.order_num = i.order_num
JOIN customer c ON c.customer_num = o.customer_num
JOIN product_types pt ON pt.stock_num = i.stock_num
-- Filtramos (podria estar en el HAVING, arriba aclaramos porque)
WHERE pt.description = (
	-- Seleccionamos solo UNA columna, porque tenemos estamos igualando a un escalar
	-- (si devolvieramos mas columnas fallaria la igulación con pt.description del WHERE)
	SELECT TOP 1 pt2.description
	-- Relacionamos de nuevo los datos por FK/PK como en la query principal
	FROM product_types pt2
	JOIN items i2		ON i2.stock_num = pt2.stock_num
	JOIN orders o2		ON o2.order_num = i2.order_num
	-- Aca nos damos cuenta que es una Subconsulta Correlacionada,
	-- por el (c2.state = c.state) <-- la columna c.state es de la Query principal
	JOIN customer c2	ON (c2.customer_num = o2.customer_num AND c2.state = c.state)
	-- agrupamos por el criterio que queriamos
	GROUP BY pt2.description, c2.state
	-- ordenamos de manera ascendente por una funcion de agregacion
	ORDER BY SUM(i2.quantity) DESC
)
GROUP BY pt.description, c.state
ORDER BY SUM(i.quantity) DESC

/*
-- algo asi era al principio,
-- el enunciado no era claro, decia elegir solo los primeros 5 estados
SELECT TOP 5 state, (
	SELECT TOP 1
	pt.description --, c.state , SUM(i.quantity)
	FROM items i
	JOIN orders o	ON o.order_num = i.order_num
	JOIN customer c ON c.customer_num = o.customer_num AND c.state = s.state
	JOIN product_types pt ON pt.stock_num = i.stock_num
	GROUP BY pt.description, c.state
	HAVING c.state = s.state
	ORDER BY SUM(i.quantity) DESC
) description
FROM state s;
*/

--------------------------------------------------------------------

/*****************
*** Ejercicio (5) <- costó un poquito :(
*/
SELECT c.customer_num, fname, lname, paid_date, SUM(i.quantity*i.unit_price) monto_total
FROM customer c
LEFT JOIN orders o	ON o.customer_num = c.customer_num
LEFT JOIN items i	ON i.order_num = o.order_num
--> (1) filtramos por la ultima orden de cada cliente
WHERE
	o.order_num = (SELECT MAX(order_num) FROM orders WHERE customer_num=c.customer_num)
--> (2) importante..! porque dice que "el cliente puede no tener ordenes"
	OR c.customer_num NOT IN (SELECT customer_num FROM orders)
--> (3) es necesario la columna "o.order_num" acá! para subquery correlacionada
GROUP BY c.customer_num, fname, lname, paid_date, o.order_num
HAVING
	SUM(i.quantity*i.unit_price) >= (
		SELECT SUM(i2.quantity*i2.unit_price) / COUNT(DISTINCT o2.order_num)
		--FROM orders o2 JOIN items i2  ON i2.order_num = o2.order_num
		FROM items  i2 JOIN orders o2 ON o2.order_num = i2.order_num	    	  --> (4) es lo mismo el de ariba
		WHERE o.order_num > o2.order_num AND o2.customer_num =c.customer_num  --> (5) importante..! el o.order_num > o2.order_num
	)
  --> (6) Hay que evaluar si es NULL, porque incluye a los que "no tengan ordenes"
	OR SUM(i.quantity*i.unit_price) IS NULL
ORDER BY SUM(i.quantity*i.unit_price) DESC

--------------------------------------------------------------------

/**********
* Ejercicio (6)
*
* 1. Usar COALESCE
* Para reemplazar no el NULL por 0, cuando comparamos con operadores relacionales >,<,>=,<=
* porque..  numero > NULL siempre dará FALSE..!
*
* 2. Criterios en GROUP BY de subquery
* Cuando comparamos resultados de la query principal, que
* tiene el mismo criterio de agrupacion o.. similar
*/

SELECT i.stock_num, description, manu_code,
		SUM(quantity) cantidad_vendida,
		SUM(quantity*unit_price) monto_total
FROM items i
JOIN product_types pt ON pt.stock_num = i.stock_num
GROUP BY manu_code, i.stock_num, description
HAVING SUM(quantity) >= ( --> (1) comparo los fabricantes que mas vendieron
	--> (2) si no reemplazamos el NULL por 0, siempre dará FALSE
	--> (numero > NULL) es FALSE  <<<---- IMPORTANTE..!
	COALESCE((SELECT TOP 1 SUM(quantity) FROM items
	WHERE
		manu_code != i.manu_code  --> comparamos contra otros fabricantes
		AND i.stock_num = stock_num --> comparo el mismo producto
	--> (3) agrupamos por un criterio..
	--> criterio: cada producto de cada fabricante
	GROUP BY stock_num, manu_code), 0)
)
ORDER BY i.stock_num, monto_total DESC, cantidad_vendida DESC

