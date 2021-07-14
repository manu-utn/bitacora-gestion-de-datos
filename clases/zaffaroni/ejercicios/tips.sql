/**
* COALESCE:
* - Usa 2 parametros => (columna_null, valor_a_mostrar)
*		a) El primero es la posible columna a tener null
* -		b) El segundo el valor que reemplazará el valor NULL
* - Es necesario si usamos "funciones de agregación" (sum,avg,count,...)
*	caso contrario no sumará o no contará esos registros
* - Es necesario si comparamos valores con los operadores <,>,>=, <=
* porque n > NULL siempre dará FALSE (suponiendo que n es un numero...)
*/
SELECT c1.customer_num,c1.lname+', '+c1.fname Referido,
COALESCE('Referido por: '+c2.lname+', '+c2.fname,'Cliente Directo')
--'Referido por: '+c2.lname+', '+c2.fname+'Cliente Directo'
--Referente
FROM CUSTOMER c1 LEFT JOIN CUSTOMER c2
ON (c1.customer_num_referedBy=c2.customer_num)

/**
* COALESCE:
* - Los parametros deben ser del mismo tipo, caso contrario castear/convertir a un solo tipo
* - En este ejemplo pasamos la fecha a char, para coincidir con el tipo de dato que se mostrará si la columna
*	de order_date es NULL
*/

SELECT c.customer_num,
COALESCE(CONVERT (char, MAX(order_date)),'No posee Productos') ultima_compra
FROM customer c LEFT JOIN orders o ON c.customer_num=o.customer_num
GROUP BY c.customer_num


-------------------------------------------------------------------------------------

/*
* Condicion en el WHERE o en el ON para JOINs
*
* (1) Para el INNER JOIN, es lo mismo si va en el WHERE ó en el ON del JOIN
*/
SELECT c.customer_num,c.lname, order_num FROM customer c
JOIN orders o ON (c.customer_num=o.customer_num AND lname='Higgins') -->

SELECT c.customer_num,c.lname, order_num FROM customer c
INNER JOIN orders o ON c.customer_num=o.customer_num
WHERE lname='Higgins' -->


/*
* Condicion en el WHERE o en el ON para OUTER JOINs
*
* (2) Para el OUTER JOIN, no es lo mismo poner la condición en el WHERE ó en el ON del OUTER JOIN
*/

-- 1. La tabla "customer" es la "tabla dominante" y se mostrarán TODOS sus registros
-- 2. En la tabla "orders" las condiciones se aplican solo a los datos de ese conjunto
--	  es decir sus columnas pueden venir NULL, pero NO afecta a la "tabla dominante"
SELECT c.customer_num,c.lname, order_num
FROM customer c --> tabla dominante
LEFT JOIN orders o ON (c.customer_num=o.customer_num AND lname='Higgins')

-- En este caso la condición del WHERE aplica para todo el conjunto
-- es decir a la tabla resultante entre customer+order
SELECT c.customer_num,c.lname, order_num
FROM customer c --> tabla dominante
LEFT JOIN orders o ON c.customer_num=o.customer_num
WHERE lname='Higgins'
