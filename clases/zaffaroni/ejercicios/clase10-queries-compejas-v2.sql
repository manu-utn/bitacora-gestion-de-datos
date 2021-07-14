-- Alternativa #1: JOIN con Subquery
SELECT m.manu_code, m.manu_name, COUNT(DISTINCT p.stock_num) cant_producto, MAX(t2.order_date) ultima_fecha_orden
FROM manufact m
LEFT JOIN products p ON p.manu_code = m.manu_code
LEFT JOIN (
		SELECT o.order_date, stock_num, manu_code --> la 2da y 3er columna son necesarias para el JOIN con la query principal
		FROM items i
		LEFT JOIN orders o 
		ON o.order_num = i.order_num --AND i.manu_code=m.manu_code --> Esto NO se puede, manu_code viene son muchas filas agrupadas
) as t2 ON t2.stock_num=p.stock_num AND t2.manu_code=m.manu_code
GROUP BY m.manu_code, m.manu_name
HAVING COUNT(DISTINCT p.stock_num) > 2 OR COUNT(DISTINCT p.stock_num) = 0
ORDER BY 3

-- Alternativa #2: JOINs
SELECT m.manu_code, m.manu_name,
COUNT(DISTINCT p.stock_num) cant_producto, MAX(order_date) ultima_fecha_orden
FROM manufact m --> Tabla "dominante"
LEFT JOIN products p ON p.manu_code=m.manu_code
LEFT JOIN items i ON i.stock_num = p.stock_num --> alternativa subquery items+orders
LEFT JOIN orders o ON o.order_num = i.order_num
GROUP BY m.manu_code, m.manu_name
HAVING COUNT(DISTINCT p.stock_num) > 2 OR COUNT(DISTINCT p.stock_num) = 0
ORDER BY 3

-- Alternativa #3: Subquery correlacionada
SELECT m.manu_code, m.manu_name, (
	SELECT MAX(o.order_date) FROM items i
	LEFT JOIN orders o ON o.order_num = i.order_num AND i.manu_code=m.manu_code
	) ultima_fecha_orden,
	COUNT(DISTINCT stock_num) cant_producto
FROM manufact m
LEFT JOIN products p ON p.manu_code = m.manu_code
GROUP BY m.manu_code, m.manu_name
HAVING COUNT(DISTINCT p.stock_num) > 2 OR COUNT(DISTINCT p.stock_num) = 0
