/*
* PRACTICA (1) DE....
*/

-- Ejercicio 14
SELECT * FROM dbo.customer
       WHERE city='CA'
       ORDER BY company;

-- Ejercicio 15
-- Duda: Porque la linea comentada NO funciona??
SELECT manu_code, count(*) as cant_productos,
     SUM(unit_price*quantity) as total_comprado
       FROM dbo.items
       GROUP BY manu_code
       HAVING SUM(unit_price*quantity) > 1500
       --HAVING total_comprado > 1500
       ORDER BY cant_productos DESC;

-- Ejercicio 16
SELECT manu_code, stock_num, quantity, SUM(quantity*unit_price) as total_vendido
       FROM dbo.items
       WHERE manu_code LIKE '_R%'
       GROUP BY manu_code, stock_num, quantity
       ORDER BY manu_code, stock_num;

-- Ejercicio 17
-- Obs: NO confundir la sintáxis de agregar mútiples filas..
-- es SELECT campos INTO #tablaTemporal FOM tabla_origen
SELECT
       customer_num, COUNT(*) as cant_ordenes,
       MIN(order_date) as primera_fecha, MAX(order_date) as ultima_fecha
       INTO #OrdenesTemp
       FROM orders
       -- es necesario GROUP BY de la columna que no tiene una "función agregada"
       GROUP BY customer_num;

-- Duda: En la resolución compara con un string pero da error (?) entonces?
SELECT * FROM #OrdenesTemp
       WHERE YEAR(primera_fecha) < 2015 AND MONTH(primera_fecha)<5 AND DAY(primera_fecha)<23
       ORDER BY ultima_fecha DESC;

-- Ejercicio 18
SELECT cant_ordenes, COUNT(*) as cant_clientes
       FROM #OrdenesTemp o1
       -- NO era necesario usar JOIN
       --INNER JOIN #OrdenesTemp o2 ON o1.cant_ordenes=o2.cant_ordenes
       GROUP BY cant_ordenes
       -- 1 es el número de columna
       ORDER BY 1 DESC;

-- Ejercicio 20
SELECT COUNT(customer_num) as cant_clientes, state, city, company
	FROM dbo.customer
       WHERE (zipcode BETWEEN 93000 AND 94100)
              AND (city <> 'Mountain View')
	      AND company LIKE '%ts%'
       GROUP BY state, city, company
       ORDER BY city;

-- Ejercicio 21
SELECT state, COUNT(*) as cant_referidos
       FROM dbo.customer
       WHERE company LIKE '[A-L]%' AND customer_num_referedBy IS NOT NULL
       -- necesitamos usar GROUP BY
       -- por estar usando COUNT() una "función agregada"
       GROUP BY state;

-- Ejercicio 22
-- Ejercicio 23


/*
* PRACTICA (2) DE INSERT, UPDATE Y DELETE
*/

-- Ejercicio 1
-- Ojo..! Te estabas confundiendo en el orden
SELECT * INTO #clientes
       FROM dbo.customer;

-- Ejercicio 2
INSERT INTO #clientes (customer_num, fname, lname, company, state, city)
       VALUES (144, 'Agustin', 'Creevy', 'Jaguares SA',
       'CA', 'Los Angeles');

-- Ejercicio 3
-- Creamos la tabla de forma "implícita"
SELECT * INTO #clientesCalifornia
       FROM dbo.customer
       WHERE 0>1;

-- insertamos multiples filas
-- Ojo de nuevo..! el select NO es una subquery, no usar paréntesis
INSERT INTO #clientesCalifornia
       SELECT * FROM dbo.customer WHERE state='CA';

-- Ejercicio 4
-- Ojo de nuevo..! el select NO es una subquery, no usar paréntesis
INSERT INTO #clientes (customer_num, fname, lname, company, address1, address2, city, state, zipcode, phone)
       SELECT 155, fname, lname, company, address1, address2, city, state, zipcode, phone
       FROM dbo.customer WHERE customer_num=103;

-- Ejercicio 5
DELETE FROM #clientes
       WHERE zipcode > 94000 AND zipcode < 94050 AND city LIKE 'M%';

-- Ejercicio 5 (alternativa usando BETWEEN)
DELETE FROM #clientes
       WHERE zipcode BETWEEN 94000 AND 94050 AND city LIKE 'M%';

-- Ejercicio 6
-- Obs: No sabias que la subquery devolveria una resultado
-- que podía reutilizar el NOT IN de la cláusula WHERE
DELETE FROM #clientes
       WHERE customer_num NOT IN (SELECT DISTINCT customer_num FROM dbo.orders)

-- Ejercicio 7
-- Obs: Ojo.. con el UPDATE, NO lleva FROM, solo la instrucción SELECT..!
SELECT * FROM #clientes WHERE status='CO';
UPDATE #clientes
       SET state='AK', address2='Barrio Las Heras'
       WHERE state='CO';

-- Ejercicio 8
UPDATE #clientes
       -- concátenamos los strings
       SET phone='1'+phone

-- Ejercicio 9
BEGIN TRANSACTION
      INSERT INTO #clientes (customer_num, lname, state, company)
      VALUES (166, 'apellido', 'CA', 'nombre empresa')
      DELETE FROM #clientesCalifornia;
-- consultamos si se realizó el transaction
SELECT * FROM #clientes WHERE customer_num=166;
SELECT * FROM #clientesCalifornia;
-- deshacemos las operaciones del transaction
ROLLBACK TRANSACTION;
-- validamos que se revertimos las operaciones del transaction
SELECT * FROM #clientes WHERE customer_num=166;
SELECT * FROM #clientesCalifornia;


-- Ejercicio 10
BEGIN TRANSACTION
      INSERT INTO #clientes (customer_num, lname, state, company)
      VALUES (166, 'apellido', 'CA', 'nombre empresa')
      DELETE FROM #clientesCalifornia;
COMMIT TRANSACTION
-- validamos si se aplicaron las operaciones del transaction
SELECT * FROM #clientes WHERE customer_num=166;
SELECT * FROM #clientesCalifornia;

