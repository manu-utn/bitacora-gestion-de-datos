-- Ejercicio (1)
SELECT 
	c.customer_num, lname, fname,
	SUM(i.quantity*i.unit_price) 'Total del Cliente',
	(SELECT COUNT(DISTINCT order_num) FROM orders) 'Cant. Total OC'
FROM customer c
JOIN orders o ON o.customer_num=c.customer_num
JOIN items  i ON i.order_num=o.order_num
WHERE c.zipcode LIKE '94%' --> El % solo funciona con el LIKE
GROUP BY c.customer_num, lname, fname
HAVING 
	(SUM(i.quantity*i.unit_price)/COUNT(DISTINCT o.order_num)) >
	 (SELECT SUM(quantity*unit_price)/COUNT(DISTINCT order_num) FROM items)
	AND COUNT(DISTINCT o.order_num) >= 2

/************************************************************************/
-- Ejercicio (2)

/*
* Alternativa #1: JOIN+Subquery con JOIN <-- "quizas no es tan claro estar devolviendo esas dos columnas"
* - La subquery relaciona los fabricantes con los productos
* - devuelve los que tengan mas de 10 productos diferentes <- resultado
* - asociamos los items con ese conjunto de datos
*/
--DROP TABLE #ABC_Productos;
--SELECT * FROM #ABC_Productos;

SELECT 
	i.stock_num, i.manu_code, description, m.manu_name,
	SUM(i.unit_price*i.quantity) 'u$',
	SUM(quantity) 'Unid. por producto'
INTO #ABC_Productos
FROM items i
JOIN (
	SELECT m2.manu_code, m2.manu_name FROM manufact m2
	JOIN products p2 ON p2.manu_code=m2.manu_code
	GROUP BY m2.manu_code, m2.manu_name HAVING COUNT(DISTINCT stock_num) >= 10
) m ON m.manu_code=i.manu_code
JOIN product_types pt ON pt.stock_num=i.stock_num
GROUP BY i.stock_num, i.manu_code, description, m.manu_name

/*
* Alternativa #2: JOIN+Subquery <--- "mas clara que la anterior, solo usa lo necesario de los productos fabricados"
* - Devuelve los productos de fabricantes que hayan fabricado 10 productos diferentes <- resultado subquery
* - Asocia el resultado de la subquery (fabricantes filtrados) con los fabricantes asociados con los items vendidos
*/
SELECT 
	i.stock_num, i.manu_code, description, m.manu_name,
	SUM(i.unit_price*i.quantity) 'u$',
	SUM(quantity) 'Unid. por producto'
INTO #ABC_Productos
FROM items i
JOIN manufact m ON m.manu_code=i.manu_code
JOIN (
	SELECT manu_code FROM products 
	GROUP BY manu_code HAVING COUNT(DISTINCT stock_num) >= 10
) p ON p.manu_code=m.manu_code
JOIN product_types pt ON pt.stock_num=i.stock_num
GROUP BY i.stock_num, i.manu_code, description, m.manu_name

/*
* Alternativa #3: JOINs + Subquery en el WHERE
* - Asocia los items vendidos, con los fabricantes y tipos de productos
* - Luego solo filtra  los fabricantes por el WHERE
*/

SELECT 
	i.stock_num, i.manu_code, description, manu_name,
	SUM(unit_price*quantity) 'u$ por Producto',
	SUM(quantity) 'Unid. por Producto'
INTO #ABC_Productos
FROM items i
JOIN manufact m ON (i.manu_code = m.manu_code)
JOIN product_types s ON (i.stock_num = s.stock_num)
WHERE i.manu_code IN ( 
	SELECT s2.manu_code FROM products s2 ------------------------->
	GROUP BY s2.manu_code HAVING COUNT(*) >= 10 ----------------->
	)
GROUP BY i.stock_num, i.manu_code, description, manu_name
ORDER BY 1

/************************************************************************/
-- Ejercicio (3)

SELECT * FROM #ABC_Productos;

SELECT 
	MONTH(order_date) mes, c.fname+','+lname cliente,
	COUNT(DISTINCT o.order_num) 'Cant. OC por mes',
	SUM(i.quantity) 'Unid Producto por mes',
	SUM(i.quantity*i.unit_price) 'u$ Producto por mes'
FROM #ABC_Productos abcp
JOIN items i    ON (i.stock_num = abcp.stock_num AND i.manu_code=abcp.manu_code) --> OJO! Clave compuesta
JOIN orders o   ON o.order_num = i.order_num
JOIN customer c ON c.customer_num = o.customer_num
WHERE c.state = (
	SELECT TOP 1 state FROM customer
	GROUP BY state
	ORDER BY COUNT(customer_num) DESC
)
GROUP BY MONTH(order_date), fname, lname, description
ORDER BY MONTH(order_date) ASC, description ASC, SUM(i.quantity) DESC


/************************************************************************/
-- Ejercicio (4)

/*
* Alternativa #1: JOIN + Subquery
*
* - La diferencia con la respuesta de la resolución, es que ellos usan un 3 JOINs para el 2do cliente, sus compras y productos de c/compra
* mientras que nosotros agrupamos esos JOINS en una subquery de un JOIN..
* Asociamos todos los datos del otro cliente, y luego seleccionamos las columnas que vamos
* a utilizar fuera de la subquery, osea en la query principal (accediendo al alias t2)
*
* - NO es necesario usar los GROUP BY, porque no queremos reducir la cant. de registros
* está pidiendo de cada producto
*
* - Es IMPORTANTE e las subqueries del WHERE el asociar al codigo del fabricante y el codigo del producto
* con los resultados de cada cliente
*/

SELECT 
	DISTINCT i.stock_num, i.manu_code , c.customer_num, c.lname , t2.customer_num, t2.lname
FROM items i
JOIN orders o    ON o.order_num=i.order_num
JOIN customer c  ON c.customer_num=o.customer_num
JOIN (
	SELECT stock_num, c2.customer_num, c2.lname, i2.manu_code
	FROM items i2
	JOIN orders o2   ON o2.order_num    = i2.order_num
	JOIN customer c2 ON c2.customer_num = o2.customer_num
	--GROUP BY stock_num, c2.customer_num, c2.lname ---> NO es necesario agrupar
) t2 ON t2.stock_num = i.stock_num AND t2.manu_code=i.manu_code --AND c2.customer_num != c.customer_num
WHERE
	i.manu_code = 'ANZ' AND i.stock_num IN (5,6,9) 
	AND
		(SELECT SUM(quantity) FROM items i3 
		JOIN orders o3 ON o3.order_num = i3.order_num
		WHERE o3.customer_num = c.customer_num
			AND i3.manu_code=i.manu_code AND i3.stock_num=i.stock_num --> Importante estas 2 condiciones, el producto y fabricante debe coincidir con el cliente 1
		)
	>
		(SELECT SUM(quantity) FROM items i4 
		JOIN orders o4 ON o4.order_num = i4.order_num 
		WHERE o4.customer_num = t2.customer_num 
			AND i4.manu_code=t2.manu_code AND i4.stock_num=t2.stock_num --> Importante estas 2 condiciones, el producto y fabricante  debe coincidir con el cliente 2
		)
--GROUP BY i.stock_num, i.manu_code, c.customer_num, c.lname, c2.customer_num, c2.lname ---> NO es necesario agrupar
--HAVING SUM(i.quantity) > SUM(c2.quantity) ---> NO sirve filtrar con funciones de agregacion, si NO están también en el SELECT
ORDER BY i.stock_num, i.manu_code


/*
* Alternativa #2: JOINS
* - Similar a a la resolucion, un poco mas claro que el anterior :(
*/

SELECT 
	DISTINCT i1.stock_num, i1.manu_code , c1.customer_num, c1.lname,
	 c2.customer_num, c2.lname
FROM items i1
JOIN orders		o1	ON o1.order_num		= i1.order_num
JOIN customer	c1	ON c1.customer_num	= o1.customer_num

JOIN items		i2	ON i2.stock_num		= i1.stock_num AND i2.manu_code=i1.manu_code
JOIN orders		o2	ON o2.order_num		= i2.order_num
JOIN customer	c2	ON c2.customer_num	= o2.customer_num
WHERE 
	i1.stock_num IN (5,6,9)
	AND i1.manu_code = 'ANZ'
	AND 
	(SELECT SUM(quantity) FROM items i3 JOIN orders o3 ON o3.order_num = i3.order_num
		WHERE 
			i3.stock_num = i1.stock_num AND i3.manu_code = i1.manu_code  --> fundamental coincida con los de la query principal
			AND o3.customer_num=c1.customer_num --> lo asociamos al primer cliente (query principal)
	)
	>
	(SELECT SUM(quantity) FROM items i4 JOIN orders o4 ON o4.order_num = i4.order_num
		WHERE 
			i4.stock_num = i2.stock_num AND i4.manu_code = i2.manu_code --> fundamental coincida con los de la query principal
			AND o4.customer_num=c2.customer_num --> lo asociamos al segundo cliente (query principal)
	)
ORDER BY i1.stock_num, i1.manu_code


/************************************************************************/
-- Ejercicio (5) <-- Costó un poquito
--
-- Lo importante acá es separar los tantos, 
-- 1. En una subquery consultás por los datos generales
-- 2. En la query principal consultás los datos de la subquery

SELECT	--> (2) consultamos por los datos de la subquery
		MAX(t.cant_od) max_cant_od, MAX(t.monto_total) max_monto_total, MAX(t.cant_prod) max_cant_prod, 
		MIN(t.cant_od) min_cant_od, MIN(t.monto_total) min_monto_total, MIN(t.cant_prod) min_cant_prod
FROM ( --> (1) En una query aparte (subquery) consultamos por todas las cantidades agrupadas por clientes
	SELECT	COUNT(DISTINCT o.order_num) cant_od, SUM(quantity*unit_price) monto_total, SUM(quantity) cant_prod
	FROM orders o
	JOIN customer	c ON c.customer_num = o.customer_num
	JOIN items		i ON i.order_num	= o.order_num
	GROUP BY o.customer_num
) as t

/*
--
-- > Problema ESTO ESTA MAL...! <---	NO estamos evaluando un conjunto de datos por separado, osea de manera individual
--								<---	se está trabajando sobre el mismo conjunto 
--
-- > Solucion: Hacer una subconsulta con un resultado general, y en el SELECT aplicar las "funciones de agregación"
--
SELECT TOP 1 COUNT(DISTINCT i.order_num) 'mayor cant OD', SUM(quantity*unit_price) 'mayor total en u$', SUM(quantity) 'mayor cant. prod',
		COUNT(DISTINCT i.order_num) 'menor cant OD', SUM(quantity*unit_price) 'menor total en u$', SUM(quantity) 'menor cant. prod'
FROM orders o
	JOIN items i ON i.order_num = o.order_num
	JOIN customer c ON c.customer_num =o.customer_num
GROUP BY o.customer_num 
ORDER BY 1 DESC, 2 DESC, 3 DESC, 4 ASC, 5 ASC, 6 ASC
*/



/************************************************************************/
-- Ejercicio (6)  <-- costó un poquito :(
-- 
SELECT c.customer_num, i.order_num, SUM(i.quantity*i.unit_price) montoTotal
FROM orders o
JOIN items		i ON i.order_num	= o.order_num
JOIN customer	c ON c.customer_num = o.customer_num
WHERE	c.state = 'CA'
		AND YEAR(order_date) = 2015
		--AND COUNT(i.order_num) >= 4 --> nope, "funciones de agregación" para filtrar solo en el HAVING..! >:(
		AND c.customer_num IN (
			SELECT c2.customer_num FROM customer c2
			JOIN orders o2 ON o2.customer_num = c2.customer_num
			WHERE YEAR(o2.order_date) = 2015
			GROUP BY c2.customer_num HAVING COUNT(o2.order_num) >= 4
		)
GROUP BY c.customer_num, i.order_num --> ahora si, podemos agrupar por cliente y sus ordenes de compra
HAVING	--> comparamos la cant. de productos de c/orden de c/cliente
		--SUM(i.quantity) > ( --> el enunciado pedia items, no cant. de productos de la orden de compra
		COUNT(i.item_num) > (
		SELECT TOP 1 COUNT(i2.item_num) FROM orders o2
		JOIN items		i2 ON i2.order_num		= o2.order_num
		JOIN customer	c2 ON c2.customer_num	= o2.customer_num
		WHERE c2.state = 'AZ' AND YEAR(o2.order_date) = 2015
		GROUP BY o2.order_num
		ORDER BY 1 DESC
		)

/************************************************************************/
-- Ejercicio (7) <--- Costó un poquito
SELECT TOP 1
	s.state, s.sname, c1.lname+','+c1.fname,
	c2.lname+','+c2.fname ,t1.total+t2.total
FROM state s
JOIN customer c1 ON c1.state = s.state --'CA'	<-- (1) en ambos NO es necesario porque luego
JOIN customer c2 ON c2.state = s.state --'CA'	<--		en el WHERE de la query principal
JOIN (										--  <--		con poner s.state= 'CA', lo aplica a las 3 columnas
	SELECT /*TOP 1*/ SUM(unit_price*quantity) as total, o.customer_num
	FROM orders o JOIN items i ON i.order_num = o.order_num
	GROUP BY o.customer_num
	--HAVING o.customer_num = c1.customer_num	--> (2) NO se puede igualar, porque c1.customer_num es un conjunto, seria como decir 1=={1,2,3}
	--ORDER BY SUM(unit_price*quantity) DESC	--> (3) La idea era usarlo en conjunto con 'TOP 1', pero NO tiene sentido
) t1 ON t1.customer_num = c1.customer_num		-->		ya que con el JOIN la idea es asociar conjuntos, no un conjunto con un escalar
JOIN (
	SELECT /*TOP 1*/ SUM(unit_price*quantity) as total, o.customer_num
	FROM orders o JOIN items i ON i.order_num = o.order_num
	GROUP BY o.customer_num
	--ORDER BY SUM(unit_price*quantity) DESC										 --> idem (3)
) t2 ON t2.customer_num = c2.customer_num --AND t2.customer_num != c1.customer_num	 --> funciona pero.. quizás conviene más en el WHERE (?)
WHERE s.state = 'CA' AND c1.customer_num > c2.customer_num
ORDER BY 5 DESC
/*
-- > Problemas que presenta esta solución..
-- > 1. NO podes obtener por separado el $$$ de c/cliente
-- > 2. El WHERE de la query principal no sirve, solo filtras un cliente (c1)

SELECT TOP 1 c1.state, c1.fname, c2.lname,
	(SELECT SUM(unit_price*quantity) FROM orders o1 
	JOIN items i1 ON i1.order_num=o1.order_num
	WHERE customer_num IN (c1.customer_num, c2.customer_num)
	)
FROM customer c1
JOIN customer c2 ON c2.customer_num != c1.customer_num
WHERE c1.state = 'CA'
		AND c1.customer_num IN(
			SELECT TOP 2 customer_num FROM orders o JOIN items i ON i.order_num = o.order_num
			GROUP BY customer_num ORDER BY SUM(unit_price*quantity) DESC
		)
*/


/************************************************************************/
-- Ejercicio (8)
-- OJO..! NO olvidarse de los "DISTINCT"
-- Podes usar el DISTINCT con el TOP asi --> "SELECT DISTINCT TOP col1, col2, .."
SELECT /*TOP 5*/ DISTINCT o.order_num, o.customer_num,  order_date, NULL 'fecha modificada'
FROM orders o
JOIN items i ON i.order_num = o.order_num
JOIN ( --> (1) obtenemos al cliente que mas productos compró del fabricante 'anz'
	SELECT TOP 1 o2.customer_num, SUM(quantity) monto_total
	FROM orders o2
	JOIN items i2 ON i2.order_num = o2.order_num
	WHERE i2.manu_code = 'ANZ'
	GROUP BY o2.customer_num
	ORDER BY SUM(quantity) DESC
) t1 ON o.customer_num = t1.customer_num --> (2) lo asociamos para obtener sus OD
--) t1 ON o.order_num=t1.order_num --> ERROR..! la idea es asociar al cliente con las OD, y luego verificar que sean las ultimas 5
WHERE manu_code = 'ANZ'
AND o.order_num IN ( --> (3) chequeamos que sean las ultimas 5 ordenes de compra con productos del fabricante ANZ
	SELECT DISTINCT TOP 5 o3.order_num FROM orders o3 --> "SELECT DISTINCT TOP campo"
	JOIN items i3 ON i3.order_num = o3.order_num
	WHERE i3.manu_code = 'ANZ'
	ORDER BY order_num DESC
)
UNION 
SELECT DISTINCT o4.order_num, o4.customer_num, order_date,
		(o4.order_date + lead_time + 1) 'fecha modificada'
FROM orders o4
JOIN items i4 ON i4.order_num = o4.order_num
JOIN ( --> (4) obtenemos al cliente que mas productos compró del fabricante 'anz'
	SELECT TOP 1 o5.customer_num, SUM(quantity) monto_total
	FROM orders o5
	JOIN items i5 ON i5.order_num = o5.order_num
	WHERE i5.manu_code = 'ANZ'
	GROUP BY o5.customer_num
	ORDER BY SUM(quantity) DESC
) t2 ON o4.customer_num != t2.customer_num --> (5) chequeamos que NO sea el que más productos compró
JOIN manufact m ON m.manu_code=i4.manu_code --> (7) para obtener el leadtime y sumarlo a las columnas del SELECT
WHERE i4.manu_code = 'ANZ'
AND o4.order_num IN ( --> (6) chequeamos que sean las ultimas 5 ordenes de compra con productos del fabricante ANZ
	SELECT DISTINCT TOP 5 o6.order_num FROM orders o6 --> "SELECT DISTINCT TOP campo"
	JOIN items i6 ON i6.order_num = o6.order_num
	WHERE i6.manu_code = 'ANZ'
	ORDER BY order_num DESC
)
ORDER BY 4

/************************************************************************/
-- Ejercicio (9)

SELECT c.customer_num, fname,lname, state,
		COUNT(DISTINCT o.order_num) cant_od,
		SUM(quantity*unit_price) monto_total
FROM customer c
JOIN orders o	ON o.customer_num	= c.customer_num
JOIN items i	ON i.order_num		= o.order_num
WHERE	state != 'WI'
GROUP BY c.customer_num, fname,lname, state
HAVING SUM(quantity*unit_price) > (
			SELECT SUM(quantity*unit_price)/COUNT(DISTINCT o2.order_num)
			FROM orders o2
			JOIN items i2 ON i2.order_num = o2.order_num
		)
