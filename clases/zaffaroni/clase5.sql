/*
* CORREGIR O REVISAR en el .org de la clase 05 
*
* En una parte preguntas si las columnas virtuales, son campos calculados
* el profe te respondió que SI
*
* VIEWS
* 1. En el ejemplo 1 de Insertar registros, 
* en la segunda query dice clientes, deberia decir v_clientes_brasil
*
* 2.En el actualizar registros
* tira error porque no cuple con el check point? o solo no muestra el registro modificado?
*
* 3. En el ejemplo 3,
* usamos GROUP BY siempre cuando usamos "funciones agregadas" como count() sum() avg(), ..
* son funciones que devuelven solo un registro como resultado (una sola fila)
*/


------------------------------------------------------------------------

-- Ejercicio 1
-- Obs: Es importante colocar en la primera columna customer_num
-- el alias o nombre de la tabla, porque sino existe AMBIGUEDAD
-- (el motor no puede reconocer que columna agarrar de las dos tablas)
SELECT c.customer_num, company, order_num
FROM customer c
JOIN orders o ON c.customer_num = o.customer_num
ORDER BY 1;

-- alternativa
SELECT c.customer_num, company, order_num
FROM dbo.orders o
JOIN dbo.customer c ON o.customer_num = c.customer_num
ORDER BY 1;


-- Ejercicio 2
-- Obs: Es importante colocar en las columnas manu_code, unite_price
-- para evitar AMBIGUEDAD
SELECT order_num, item_num, pt.description, i.manu_code, quantity, i.unit_price*quantity as precioTotal
FROM items i
JOIN products p ON (i.stock_num=p.stock_num AND i.manu_code=p.manu_code)
JOIN product_types pt ON p.stock_num=pt.stock_num
WHERE order_num = 1004;


-- Ejercicio 3
SELECT order_num, item_num, pt.description, i.manu_code, quantity, i.unit_price*quantity as precioTotal, manu_name
FROM items i
JOIN products p ON (i.stock_num=p.stock_num AND i.manu_code=p.manu_code)
JOIN product_types pt ON p.stock_num=pt.stock_num
JOIN manufact m ON p.manu_code=m.manu_code
WHERE order_num = 1004;


-- Ejercicio 4
SELECT order_num, c.customer_num, fname, lname, company
FROM customer c
JOIN orders o ON c.customer_num=o.customer_num;


-- Ejercicio 5
SELECT DISTINCT c.customer_num, fname, lname, company
FROM customer c
JOIN orders o ON c.customer_num=o.customer_num;

-- alternativa
SELECT DISTINCT c.customer_num, fname, lname, company
FROM orders o
JOIN customer c ON o.customer_num=c.customer_num;


-- Ejercicio 6
SELECT manu_name, p.stock_num, pt.description, unit, unit_price, unit_price*1.2 as precio_junio
FROM units u
JOIN products p ON u.unit_code=p.unit_code
JOIN product_types pt ON p.stock_num=pt.stock_num
JOIN manufact m ON p.manu_code=m.manu_code;

-- Ejercicio 7
SELECT item_num, pt.description, quantity, i.unit_price*quantity as precio_total
FROM items i
JOIN orders o ON i.order_num=o.order_num
JOIN product_types pt ON i.stock_num=pt.stock_num
--JOIN products p ON (i.stock_num=p.stock_num AND i.manu_code=p.manu_code)
--JOIN product_types pt ON p.stock_num=pt.stock_num
WHERE i.order_num = 1004
ORDER BY 1;

-- Ejercicio 8
-- Te faltó el DISTINCT
SELECT DISTINCT i.manu_code, lead_time
FROM items i
JOIN orders o ON i.order_num=o.order_num
JOIN manufact m ON i.manu_code=m.manu_code
WHERE o.customer_num=104;

-- Ejercicio 9
SELECT o.order_num, order_date, item_num, description, quantity, i.unit_price*quantity as precio_total
FROM orders o
JOIN items i ON o.order_num=i.order_num
JOIN product_types pt ON i.stock_num=pt.stock_num;

-- Ejercicio 10
/*
Obtener un listado con la siguiente información: Apellido (lname) y Nombre (fname) del Cliente
separado por coma, Número de teléfono (phone) en formato (999) 999-9999. Ordenado por
apellido y nombre.
*/
-- DUDAS: Lo del formato como sería...?

SELECT lname + ',' + fname, phone
FROM customer
ORDER BY 1,2;

-- Ejercicios pendientes: 11, 12, 13
