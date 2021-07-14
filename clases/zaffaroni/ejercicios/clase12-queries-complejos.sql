/*
* Ejercicio (9)
*/

SELECT	c.customer_num, fname, lname, state, 
		COUNT(DISTINCT o.order_num) cant_od,
		SUM(quantity * unit_price) monto_total
FROM customer c
JOIN orders o ON o.customer_num = c.customer_num
JOIN items	i ON i.order_num	= o.order_num
WHERE YEAR(order_date) = 2015 AND c.state != 'FL'
GROUP BY c.customer_num, fname, lname, state
HAVING SUM(quantity * unit_price) > (
	--> (1) el enunciado dice "promedio del monto total comprado POR CLIENTE"
	-->		si hacemos count(order_num) seria el promedio total de compras en general
	--SELECT SUM(quantity * unit_price) / COUNT(DISTINCT o2.order_num)
	SELECT SUM(quantity * unit_price) / COUNT(DISTINCT o2.customer_num)
	FROM orders o2
	JOIN items		i2 ON i2.order_num		= o2.order_num
	JOIN customer	c2 ON c2.customer_num	= o2.customer_num
	WHERE c2.state != 'FL'
	--GROUP BY o2.customer_num  --> (2) si hicieramos esto.. nos devolveria un conjunto de datos >:(
								-->		y no podriamos compararlo con el operador > por no ser un escalar
)
ORDER BY SUM(quantity * unit_price) DESC

---------------------------------------------------------------------------------------------------------------

/*
* Ejercicio (10) - Alternativa #1
*/
SELECT	c1.customer_num, c1.fname, c1.lname, SUM(i.quantity*i.unit_price) monto_total, --total_c1.monto_total,
		total_c2.customer_num, total_c2.fname, total_c2.lname, total_c2.monto_total
FROM customer c1 
LEFT JOIN orders o ON o.customer_num = c1.customer_num  --> En la alternativa #2 lo hacemos en un JOIN con subquery
LEFT JOIN items  i ON i.order_num	 = o.order_num		-->
--LEFT JOIN customer c2 ON c2.customer_num = c1.customer_num_referedBy --> (1.a) Estamos asociando MAL, asociará con clientes referidos que
																	   --> pero NO cumplen la condición del año 2015...
LEFT JOIN (
	SELECT SUM(quantity*unit_price) monto_total, o1.customer_num, fname, lname
	FROM orders o1
	JOIN customer c2	ON c2.customer_num  = o1.customer_num
	JOIN items	i1		ON i1.order_num		= o1.order_num
	WHERE YEAR(order_date) = 2015
	GROUP BY o1.customer_num, fname, lname
) total_c2 ON total_c2.customer_num = c1.customer_num_referedBy	--> (1.b) acá estaria OK, porque ya tiene la lógica del año 2015 
--) total_c2 ON total_c2.customer_num = c2.customer_num			-->	para los clientes referidos
WHERE YEAR(o.order_date) = 2015
GROUP BY c1.customer_num, c1.fname, c1.lname,
		 total_c2.customer_num, total_c2.fname, total_c2.lname, total_c2.monto_total
HAVING SUM(i.quantity*i.unit_price) > COALESCE(total_c2.monto_total, 0)
ORDER BY SUM(i.quantity*i.unit_price) DESC
------------------------

/*
* Ejercicio (10) - Alternativa #2
*/

SELECT	c1.customer_num, c1.fname, c1.lname, total_c1.monto_total,
		total_c2.customer_num, total_c2.fname, total_c2.lname, total_c2.monto_total
FROM customer c1 
JOIN ( --> Esto tiene de diferente de la alternativa #1, separamos la lógica de obtener el monto_total
	SELECT SUM(quantity*unit_price) monto_total, customer_num FROM orders o1
	JOIN items  i1 ON i1.order_num = o1.order_num
	WHERE YEAR(order_date) = 2015 
	GROUP BY customer_num
) total_c1 ON total_c1.customer_num = c1.customer_num
LEFT JOIN (
	SELECT SUM(quantity*unit_price) monto_total, o1.customer_num, fname, lname FROM orders o1
	JOIN customer c2	ON c2.customer_num  = o1.customer_num
	JOIN items	i1		ON i1.order_num		= o1.order_num
	WHERE YEAR(order_date) = 2015
	GROUP BY o1.customer_num, fname, lname
) total_c2 ON total_c2.customer_num = c1.customer_num_referedBy
WHERE total_c1.monto_total > COALESCE(total_c2.monto_total, 0) --> en la alternativa #1 la comparación es en el HAVING
GROUP BY c1.customer_num, c1.fname, c1.lname, total_c1.monto_total,
		 total_c2.customer_num, total_c2.fname, total_c2.lname, total_c2.monto_total
ORDER BY total_c1.monto_total DESC

/*
--> Con esta consulta nos dimos cuenta del error del ejercicio 10 :)

SELECT	c.customer_num, fname, lname, SUM(i.quantity*i.unit_price) monto_total, YEAR(order_date) anio
FROM customer c
LEFT JOIN orders o ON o.customer_num = c.customer_num
LEFT JOIN items  i ON i.order_num	 = o.order_num		
WHERE c.customer_num IN (103, 104) --AND YEAR(order_date) = 2015
GROUP BY c.customer_num, fname, lname, YEAR(order_date)

SELECT * FROM customer WHERE customer_num = 104
SELECT * FROM customer WHERE customer_num = 103
*/