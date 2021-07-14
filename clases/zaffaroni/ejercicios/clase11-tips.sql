-- > 1. Mostraremos el monto total de cada compra en el 2015 de cada cliente del estado 'CA'
-- > 2. filtraremos por aquellos que hayan hecho mas de 4 compras (esto lo haremos por separado en un subquery)
-- > 3. luego agruparemos por cliente y su orden de compra 
SELECT c.customer_num, o.order_num, SUM(i.unit_price*i.quantity) totalOrdenPorCliente
FROM customer c JOIN orders o ON c.customer_num=o.customer_num
LEFT JOIN items i ON o.order_num=i.order_num
WHERE c.state = 'CA' AND YEAR(o.order_date)=2015
and c.customer_num IN
	-- filtramos por los clientes que hicieron 4 compras o más en el 2015
	-- > si agrupamos por "cliente+orden de compra" => habran clientes repetidos si tuviesen varias compras
	-- >											=> relación "1 a 1" entre cliente-compra, por tanto NO podriamos contar la cant. de compras
	-- > Si agrupamos solo por cliente, no habran clientes repetidos
	(SELECT c1.customer_num, order_num
	FROM customer c1 JOIN orders o1 ON c1.customer_num=o1.customer_num
	WHERE YEAR(o1.order_date)=2015
	GROUP BY c1.customer_num --,order_num <-- NO debemos agrupar por la columna "order_num" si queremos contar la cant. de compras del cliente
	HAVING COUNT(*)>=4
	)
group by c.customer_num, o.order_num	--> Ahora "SI" podemos agrupar por "order_num" y "customer_num" (cada cliente con su compra realizada)
										--> por si queremos comparar la "cant. de items" de cada "orden de compra" con otra cantidad

---------------------------------------------------------------------------------------------------------------------------------------------
-- TIP: Cuidado al agrupar con GROUP BY..

-- > Agrupamos los clientes con sus ordenes de compra
-- > Habran clientes repetidos, si tuviesen varias compras
-- > PROBLEMA: NO podremos filtrar en el HAVING por "cantidad de compras", porque al agrupar por ambas columnas hay una relacion "1 a 1" en vez de "1 a n"
-- > SOLUCION: Agrupar solo por la columna "customer_num" suponiendo que queremos filtrar por la cant. de compras
SELECT c1.customer_num ,order_num
FROM customer c1 JOIN orders o1 ON c1.customer_num=o1.customer_num
WHERE YEAR(o1.order_date)=2015
GROUP BY c1.customer_num ,order_num
HAVING COUNT(order_num) >= 2 --> esto es un error semántico, al agrupar las columnas hay relación "1 a 1" en vez de "1 a n"
ORDER BY 1

-- Solución al problema anterior...
-- agrupamos solo por clientes
-- NO habran clientes repetidos, por mas que hagan varias compras, y podremos filtrar por la cant. de compras
SELECT c1.customer_num, COUNT(*)
FROM customer c1 JOIN orders o1 ON c1.customer_num=o1.customer_num
WHERE YEAR(o1.order_date)=2015
GROUP BY c1.customer_num HAVING COUNT(*)>=2
ORDER BY 1
---------------------------------------------------------------------------------------------------------------------------------------------
