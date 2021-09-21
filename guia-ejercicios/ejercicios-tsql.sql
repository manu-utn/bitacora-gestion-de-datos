USE GD2015C1

--------------------------------------------------------------------------------------------
--> Ejercicio (1)
--
--> Nota (1):
--> 1. En este caso es posible la asignación SELECT @variable1=col1, @variable2=col2, .. FROM tabla
--> porque se está pasando la (PK) stoc_producto+stoc_deposito que garantiza la "unicidad"
--> por tanto se asignan valores de un registro.
--
--> 2. Si la consulta hubiese devuelto varios registros, se le hubiese asignado los valores
--> del último registro que devuelva el SELECT, porque el SELECT actúa como un FOR
--> recorre cada registro del conjunto que trae el FROM y se lo va asignando cada uno
--> a las variable @producto y @deposito
--> cuando llega al ultimo registro, se quedan guardados los valores de éste
--
--> Nota (2):
--> 1. Las funciones SIEMPRE deben retornar un valor
GO
CREATE FUNCTION estado_deposito_del_articulo (@producto CHAR(8), @deposito CHAR(2))
	RETURNS CHAR(30) AS
BEGIN
	DECLARE @cant_stock DECIMAL(12,2), @stock_min  DECIMAL(12,2), @stock_max  DECIMAL(12,2)
	DECLARE @RETORNO CHAR(30)

	--> (1)
	SELECT @cant_stock=stoc_cantidad,  @stock_min=stoc_punto_reposicion, @stock_max=stoc_stock_maximo
	FROM STOCK WHERE stoc_producto=@producto AND stoc_deposito=@deposito

	IF(@cant_stock < @stock_min)
		SET @RETORNO='OCUPACION DEL DEPOSITO ES ' + STR((@cant_stock*100)/@stock_max, 12, 2)
		-- stock_max    (200) __ 100%
		-- stock_actual (100) __ X %  => x = (actual/100)*max => x = 50%
	ELSE IF(@cant_stock > @stock_max)
		SET @RETORNO='DEPOSITO COMPLETO'

	RETURN @RETORNO --> (2)
END
GO

/*
-- Ejemplo de lo mencionado sobre como el SELECT actúa como un FOR, iterando sobre el conjunto
-- registros que trae el FROM

DECLARE @producto CHAR(8), @deposito CHAR(2)
SELECT TOP 5 @producto=stoc_producto, @deposito=stoc_deposito FROM STOCK ORDER BY stoc_producto
SELECT @producto, @deposito

SELECT TOP 5 stoc_producto, stoc_deposito FROM STOCK ORDER BY 1
*/

--------------------------------------------------------------------------------------------
--> Ejercicio (2)
--
-- La 2da query actúa de la sig. manera
--> 1. FROM: Obtiene todas las facturaciones
--> 2. JOIN: las asocia con cada producto vendido
--> 3. WHERE: filtra por fecha < @fecha y que producto=@producto
--> 4. SELECT SUM(col1): suma el valor de toda la columna, y arroja un valor escalar
--
--> Obs: se podrían haber declarado variables para mejorar la expresividad
DROP FUNCTION stock_articulo_por_fecha

GO
CREATE FUNCTION stock_articulo_por_fecha (@producto_cod CHAR(8), @fecha SMALLDATETIME)
RETURNS DECIMAL(12,2) AS
BEGIN
	RETURN (SELECT SUM(stoc_cantidad) FROM STOCK WHERE stoc_producto=@producto_cod) +
			(SELECT SUM(item_cantidad) FROM Factura f
				JOIN Item_Factura i ON i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero
				WHERE fact_fecha <= @fecha AND item_producto=@producto_cod)
			
END

-- probamos si anda ok
SELECT dbo.stock_articulo_por_fecha(item_producto, fact_fecha) FROM Factura f
	JOIN Item_Factura i
	ON i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero


--------------------------------------------------------------------------------------------
--> Ejercicio (3)

GO
CREATE PROCEDURE empleados_elegir_gerente_general @cantidad_empleados_sin_jefe INT OUT
AS
BEGIN
	DECLARE @gerente_general NUMERIC(6)
	--SELECT @cantidad_empleados_sin_jefe=COUNT(*) FROM Empleado WHERE empl_jefe IS NULL
	SET @cantidad_empleados_sin_jefe = (SELECT COUNT(*) FROM Empleado WHERE empl_jefe IS NULL)

	--SELECT TOP 1 @gerente_general=empl_codigo FROM Empleado WHERE empl_jefe IS NULL ORDER BY empl_salario DESC, empl_nacimiento ASC
	SET @gerente_general = (SELECT TOP 1 empl_codigo FROM Empleado WHERE empl_jefe IS NULL ORDER BY empl_salario DESC, empl_nacimiento ASC)

	UPDATE Empleado SET empl_jefe=@gerente_general
		WHERE empl_jefe IS NOT NULL AND empl_codigo != @gerente_general
END

/*
-- probamos solo para ver la diferencia
DECLARE @var1 INT, @var2 INT
SET @var1 = (SELECT COUNT(*) FROM Empleado WHERE empl_jefe IS NULL)
SELECT @var2=COUNT(*) FROM Empleado WHERE empl_jefe IS NULL
SELECT @var1, @var2
*/

BEGIN TRANSACTION
DECLARE @cantidad INT
EXECUTE empleados_elegir_gerente_general @cantidad
SELECT @cantidad
ROLLBACK TRANSACTION
 --> Otras variantes? ROLLBACK TRAN, ROLLBACK TRANSACTION, ROLLBACK
 --> Podemos agregar o no el TRAN ó TRANSACTION

--------------------------------------------------------------------------------------------
--> Ejercicio (4) <----- pendiente chequear
--
--> Nota (1):
--> Cuando agregamos "OUT" al declarar una variable como parametro en un PROCEDURE, 
--> es como trabajar con punteros en C, pasando un parametro "x" por referencia
--> y éste es modificado dentro de la rutina/función. En este caso dentro del procedure
--
--> Nota (2):
--> NO es necesario agrupar ni filtrar en having, es suficiente con filtrar en WHERE
--
--> Nota (3):
	-------------------------------------------------
	-- Con este query te das cuenta que debemos usar usar cursores, porque
	-- 1. Obtener el total de las ventas del ultimo año de cada empleado (en Facturas)
	-- 2. Luego modificar la comisión de cada empleado del resultado anterior (en Empleado)
	/*
	-------------------------------------------------
	-- UPDATE Empleado SET comision=.. + Join Factura + WHERE (?) se complejiza..

	SELECT empl_codigo, SUM(fact_total)
	FROM Factura f
	JOIN Empleado e ON e.empl_codigo=f.fact_vendedor
	WHERE YEAR(fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura WHERE fact_vendedor=f.fact_vendedor)
	GROUP BY empl_codigo
	-------------------------------------------------
	*/
--
DROP PROCEDURE actualizar_empleado_comision

GO
CREATE PROCEDURE actualizar_empleado_comision @cod_empleado_con_mas_ventas NUMERIC(6) OUT --> (1)
AS
BEGIN
	DECLARE @empl_codigo NUMERIC(6) --,@empl_mas_ventas NUMERIC(6)
	DECLARE @monto_venta DECIMAL(12,2)

	DECLARE EMPLEADO_CURSOR CURSOR FOR --> (3)
	SELECT empl_codigo FROM Empleado
	OPEN EMPLEADO_CURSOR
	FETCH FROM EMPLEADO_CURSOR INTO @empl_codigo
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @monto_venta = (
			SELECT SUM(fact_total) FROM Factura 
			WHERE	YEAR(fact_fecha)=( SELECT MAX(YEAR(fact_fecha)) FROM Factura WHERE fact_vendedor=@empl_codigo )
					AND fact_vendedor=@empl_codigo
			--GROUP BY fact_vendedor HAVING fact_vendedor=@empl_codigo --> (2)
		)

		UPDATE Empleado
			SET empl_comision=@monto_venta
			WHERE empl_codigo=@empl_codigo
				
		FETCH FROM EMPLEADO_CURSOR INTO @empl_codigo
	END
	CLOSE EMPLEADO_CURSOR
	DEALLOCATE EMPLEADO_CURSOR

	SET @cod_empleado_con_mas_ventas=(SELECT TOP 1 empl_codigo FROM Empleado ORDER BY empl_comision DESC)
END

/*
-- Probamos si anda ok, pero ambas queries arrojan resultados diferentes (???)

-- hacemos copia de las tablas, se crean las tablas y se hacen multiples inserciones
SELECT * INTO Empleado2 FROM Empleado
SELECT * INTO Factura2 FROM Factura

SELECT empl_codigo, SUM(empl_comision) comision_extra, COUNT(*) cant_ventas, empl_comision
FROM Empleado e
JOIN Factura f ON f.fact_vendedor=e.empl_codigo
WHERE	YEAR(fact_fecha)=( SELECT MAX(YEAR(fact_fecha)) FROM Factura WHERE fact_vendedor=empl_codigo )
GROUP BY empl_codigo, empl_comision

BEGIN TRAN
DECLARE @empleado NUMERIC(6)
EXEC actualizar_empleado_comision @empleado
--SELECT @empleado
SELECT empl_codigo , empl_comision FROM Empleado GROUP BY empl_codigo, empl_comision
ROLLBACK TRAN
*/

--------------------------------------------------------------------------------------------
--> Ejercicio (5) ---> Tiene problemas al insertar por la PK
--
-- 
Create table Fact_table
( anio char(4) NOT NULL,
mes char(2) NOT NULL,
familia char(3) NOT NULL,
rubro char(4) NOT NULL,
zona char(3) NOT NULL,
cliente char(6) NOT NULL,
producto char(8) NOT NULL,
cantidad decimal(12,2) NOT NULL,
monto decimal(12,2)  NOT NULL
)
Alter table Fact_table
Add constraint pk_fact primary key(anio, mes, familia, rubro, zona, cliente, producto)

DROP PROCEDURE actualizar_fact_table

GO
CREATE PROCEDURE actualizar_fact_table
AS
BEGIN
	--> Hacemos multiples inserciones..
	---
	-- INSERT INTO tabla1 (col1, col2, ...) <---- si queremos elegir el orden de las columnas, para evitar errores de tipos
	-- SELECT col1,col2, ... FROM tabla2
	--
	-- INSERT tabla1
	-- SELECT col1,col2, ... FROM tabla2
	--
	INSERT Fact_table
	SELECT	YEAR(fact_fecha), MONTH(fact_fecha),
			prod_familia, prod_rubro,  depo_zona, fact_cliente, prod_codigo, item_cantidad, item_precio
	FROM Producto p
	JOIN STOCK s ON s.stoc_producto=p.prod_codigo
	JOIN DEPOSITO d ON d.depo_codigo=s.stoc_deposito
	JOIN Item_Factura i ON i.item_producto=p.prod_codigo
	JOIN Factura f ON f.fact_tipo=i.item_tipo AND f.fact_sucursal=i.item_sucursal AND f.fact_numero=i.item_numero
	WHERE	prod_familia IS NOT NULL AND prod_rubro IS NOT NULL AND depo_zona IS NOT NULL
			AND fact_cliente IS NOT NULL AND prod_codigo IS NOT NULL AND item_cantidad IS NOT NULL
			AND item_precio IS NOT NULL	
	GROUP BY prod_familia, prod_rubro,  depo_zona, fact_cliente, prod_codigo, item_cantidad, item_precio, YEAR(fact_fecha), MONTH(fact_fecha)
END

/*
BEGIN TRAN
SELECT * FROM Fact_table
EXECUTE actualizar_fact_table
SELECT * FROM Fact_table
ROLLBACK TRAN
*/


--------------------------------------------------------------------------------------------
--> Ejercicio (6) <--- Le falta la lógica de actualizar el atributo cantidad, de los productos combos vendidos
--
-- Nota (2):
--> 1. Dividimos la cant. de unidades del producto vendido, por la cant. de unidades que requiere el combo.
--> Porque en (1) ya habiamos filtrado de guardar en @combo sólo combos completos
--
--> Ej. Si el "combo premium" solo tiene "2 unidades de gaseosas", y este combo se repite 6 veces
-->  entonces podemos armar 3 combos premium
/*
	1. Iteramos sobre las facturas (en realidad sobre una variable especial que es CURSOR)
	1.1 guardamos la PK que es una clave compuesta tipo+sucursal+numero

	2. Iteramos sobre cada renglón de cada factura (anidamos cursores, como si fuesen dos "for" de C)
	2.1 chequeamos que los renglones sean de la factura iterada en el 1er cursor,
		asociando la PK de la factura con el item_factura
	2.2 seleccionamos los productos que sean combo y que la cant. vendida sea igual
		a la cant. de componentes que forman el combo, para chequear que están completos
	2.3 guardamos el id de producto que es combo

	2.4 chequeamos de cada combo que cant. hay de cada uno, en cada factura
		porque pueden haber combos repetidos
	2.5 insertamos el combo en los productos vendidos, y.. deberia de borrarse los que son componentes de ese combo
*/

GO
CREATE PROCEDURE actualizar_facturas_combos
AS
BEGIN
	DECLARE @combo CHAR(8)
	DECLARE @combo_cantidad INT, @combo_precio INT
	DECLARE @fact_tipo CHAR(1), @fact_sucursal CHAR(4), @fact_numero CHAR(8)

	DECLARE FACTURA_CURSOR CURSOR
	FOR	SELECT fact_tipo, fact_sucursal, fact_numero FROM Factura
	OPEN FACTURA_CURSOR
	FETCH FROM FACTURA_CURSOR INTO @fact_tipo, @fact_sucursal, @fact_numero
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE PRODUCTO_CURSOR CURSOR
		FOR SELECT comp_producto, prod_precio FROM Item_Factura i
			JOIN Composicion c ON c.comp_producto=i.item_producto
			JOIN Producto p ON p.prod_codigo=i.item_producto
			WHERE i.item_tipo=@fact_tipo AND i.item_sucursal=@fact_sucursal AND i.item_numero=@fact_numero
			GROUP BY comp_producto, prod_precio
			HAVING COUNT(*) = (SELECT COUNT(*) FROM Composicion WHERE comp_producto=c.comp_producto) --> (1)
		OPEN PRODUCTO_CURSOR
		FETCH FROM PRODUCTO_CURSOR INTO @combo, @combo_precio --> anidamos un cursor dentro del anterior cursor
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @combo_cantidad=MIN(FLOOR(item_cantidad/comp_cantidad)) --> (2) (3)
				FROM Item_Factura i
				JOIN Composicion c ON c.comp_producto=i.item_producto
				WHERE	i.item_tipo=@fact_tipo AND i.item_sucursal=@fact_sucursal AND i.item_numero=@fact_numero
						AND comp_producto=@combo

			INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
			SELECT @fact_tipo, @fact_sucursal, @fact_numero, @combo, @combo_cantidad, @combo_precio*@combo_cantidad

			-- Faltaria la lógica de.. actualizar las cantidades de los productos facturados que son combo
			-- y borrar los productos que son componentes del combo insertado

			FETCH FROM PRODUCTO_CURSOR INTO @combo, @combo_precio
		END
		CLOSE PRODUCTO_CURSOR
		DEALLOCATE PRODUCTO_CURSOR

		FETCH FROM FACTURA_CURSOR INTO @fact_tipo, @fact_sucursal, @fact_numero
	END
	CLOSE FACTURA_CURSOR
	DEALLOCATE FACTURA_CURSOR
END

/*
-- 1. probamos de taer de cada factura, los productos vendidos que son componentes
SELECT fact_tipo+' '+fact_sucursal+' '+fact_numero, comp_producto, COUNT(*) cant_componentes
FROM Factura f
JOIN Item_Factura i ON  i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero
JOIN Composicion c ON c.comp_componente=i.item_producto
GROUP BY comp_producto, fact_tipo, fact_sucursal, fact_numero
ORDER BY 3 DESC

-- 2. Probamos contar la cant. de componentes de cada producto que es combo
SELECT comp_producto, COUNT(*) cant_componentes FROM Composicion GROUP BY comp_producto

-- 3. Asociamos de los productos vendidos cuales son combo y su precio (el del producto, no el facturado)
SELECT comp_producto, prod_precio FROM Item_Factura i
JOIN Composicion c ON c.comp_producto=i.item_producto JOIN Producto p ON p.prod_codigo=i.item_producto
GROUP BY comp_producto, prod_precio
*/


--------------------------------------------------------------------------------------------
--> Ejercicio (7) <----- pendiente chequear
--
--> Nota (1):
--> Para inserciones masivas podés usar ambas variantes
--> 1. Sin especificar las col. de la tabla:
--		INSERT VENTAS SELECT col1,col2,.. FROM tabla 
--
--> 2. Especificando las col. de la tabla
--		INSERT INTO VENTAS (col1, col2,...) SELECT col1,col2,.. FROM tabla 
--
-- OJO..! En el (2) NO estamos poniendo VALUES, eso seria para una unica inserción
-- a menos que pongas VALUES (col1,col2,..), (col1,col2,...) <- pero no sirve si usás un SELECT
DROP TABLE Ventas

CREATE TABLE Ventas(
	codigo_articulo CHAR(8),
	detalle CHAR(50),
	cant_mov DECIMAL(12,2),
	precio_venta DECIMAL(12,2),
	renglon CHAR(13),
	ganancia DECIMAL(12,2)
);

DROP PROCEDURE actualizar_ventas

GO
CREATE PROCEDURE actualizar_ventas @fecha_desde SMALLDATETIME, @fecha_hasta SMALLDATETIME
AS
BEGIN
	DECLARE @precio_venta DECIMAL(12,2), @cantidad_vendida DECIMAL(12,2)
	DECLARE @producto_id CHAR(8) --@producto_detalle CHAR(50), @producto_precio DECIMAL(12,2)
	DECLARE @fact_tipo CHAR(1), @fact_sucursal CHAR(4), @fact_numero CHAR(8)
	DECLARE @cantidad_movimientos DECIMAL(12,2), @precio_promedio_venta DECIMAL(12,2)

	DECLARE PRODUCTO_VENDIDO_CURSOR CURSOR FOR
	SELECT	item_producto, item_precio, item_cantidad,	--> datos de la venta del producto
			item_tipo, item_sucursal, item_numero		--> PK de las facturas
			--prod_codigo, prod_detalle, prod_precio	--> datos del producto
			FROM Factura f								--> dame todas las ventas
			JOIN Item_Factura i							--> dame todos los productos que se vendieron (asociando con las ventas traidas del FROM)
			ON i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero
			--JOIN Producto p ON p.prod_codigo=i.item_producto
			WHERE fact_fecha BETWEEN @fecha_desde AND @fecha_hasta
	OPEN PRODUCTO_VENDIDO_CURSOR
	FETCH FROM PRODUCTO_VENDIDO_CURSOR INTO @producto_id, @precio_venta, @cantidad_vendida, @fact_tipo, @fact_sucursal, @fact_numero --> obtiene el primer registro
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- ...
		SELECT @cantidad_movimientos=COUNT(*), @precio_promedio_venta=AVG(item_precio)
		FROM Item_Factura WHERE item_producto=@producto_id

		INSERT INTO Ventas (codigo_articulo, detalle, cant_mov, precio_venta, renglon, ganancia)  --> (1)
			SELECT prod_codigo, prod_detalle, @cantidad_movimientos, @precio_promedio_venta, @fact_numero+@fact_sucursal+@fact_tipo, @precio_venta-@cantidad_vendida*prod_precio
			FROM Producto WHERE prod_codigo=@producto_id

		FETCH FROM PRODUCTO_VENDIDO_CURSOR INTO @producto_id, @precio_venta, @cantidad_vendida, @fact_tipo, @fact_sucursal, @fact_numero --> obtiene el sig. registro
		-- ...
	END
	CLOSE PRODUCTO_VENDIDO_CURSOR
	DEALLOCATE PRODUCTO_VENDIDO_CURSOR
END
GO
----------------------------------------------------------------------------------------------------------------
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
DECLARE @fecha_primer_venta SMALLDATETIME, @fecha_ultima_venta SMALLDATETIME
SELECT @fecha_primer_venta=MIN(fact_fecha), @fecha_ultima_venta=MAX(fact_fecha) FROM Factura
SELECT @fecha_primer_venta, @fecha_ultima_venta

BEGIN TRAN
EXECUTE dbo.actualizar_ventas @fecha_primer_venta, @fecha_ultima_venta
SELECT * FROM Ventas
ROLLBACK
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


--> Notas del PROCEDURE que considero que tenia algunas fallas, pero lo dejo para reutilizar para futuros ejemplos
--
--> Nota (2):
--> 1. Agregar en el SELECT la columna item_numero, implíca que también se deba agregar en el GROUP BY
--> porque se están usando funciones de agregación COUNT() y AVG()
--
-- 2. El agrupar por item_numero, implíca que el COUNT(*) devuelva el valor 1, 
-- es decir no va a contar, porque es la PK de Item_Factura que satisface la unicidad, 
-- por tanto devolverá multiples registros y la columna del COUNT(*) dará 1
--
--> Nota (3):
	-- 1. Probamos que NO es necesario agrupar por pro_codigo, porque en el WHERE ya estamos pasando las PK que
	-- aseguran la NO repetición de los datos
	-- 2. Como es Producto JOIN Item_Factura, y en el WHERE le pasamos la PK de ambas tablas, aseguramos que
	-- obtendremos solo 1 registro
	/*
	----------------------------------------------------------------------------------------------
	SELECT * FROM Producto p
	JOIN Item_Factura i ON i.item_producto=p.prod_codigo
	WHERE	i.item_tipo='A' AND i.item_sucursal='0003' AND i.item_numero='00092444' --> (PK), asegura unicidad en Item_factura
			AND i.item_producto='00001415' --> (PK) asegura unicidad en la tabla "Producto"
			--GROUP BY prod_codigo, prod_detalle
	----------------------------------------------------------------------------------------------
	*/
/*
GO
CREATE PROCEDURE actualizar_ventas_v1 @fecha_desde SMALLDATETIME, @fecha_hasta SMALLDATETIME
AS
BEGIN
	DECLARE @prod_codigo CHAR(8), @fact_tipo CHAR(1), @fact_sucursal CHAR(4), @fact_numero CHAR(8)
	DECLARE @ganancia DECIMAL(12,2)

	DECLARE PRODUCTO_CURSOR CURSOR FOR
	SELECT item_producto, fact_tipo, fact_sucursal, fact_numero
			FROM Factura f			--> dame todas las ventas
			JOIN Item_Factura i		--> dame todos los productos que se vendieron (asociando con las ventas traidas del FROM)
				ON i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero
			WHERE fact_fecha BETWEEN @fecha_desde AND @fecha_hasta
	FETCH FROM PRODUCTO_CURSOR INTO @prod_codigo, @fact_tipo, @fact_sucursal, @fact_numero --> itera sobre cada producto vendido
	WHILE @@FETCH_STATUS = 0
	BEGIN
		 SELECT @ganancia=item_precio-item_cantidad*prod_precio
		 FROM Producto p --> para obtener el precio actual
		 JOIN Item_Factura i ON i.item_producto=p.prod_codigo --> para obtener cantidad y precio de venta
		 WHERE prod_codigo=@prod_codigo AND i.item_tipo=@fact_tipo AND i.item_sucursal=@fact_sucursal AND i.item_numero=@fact_numero

		 INSERT INTO Ventas (codigo_articulo, detalle, cant_mov, precio_venta, renglon, ganancia) --> (1)
		 SELECT prod_codigo, prod_detalle, COUNT(*), --> este count() va a devolver 1, xq estamos pasandole las (PK)
				AVG(item_precio), @fact_numero, @ganancia
		 FROM Producto p										--> para obtener los datos de los productos (detalle, precio)
		 JOIN Item_Factura i ON i.item_producto=p.prod_codigo	--> 
		 WHERE prod_codigo=@prod_codigo AND i.item_tipo=@fact_tipo AND i.item_sucursal=@fact_sucursal AND i.item_numero=@fact_numero
		 --GROUP BY prod_codigo, prod_detalle --> (3)
		FETCH FROM PRODUCTO_CURSOR INTO @prod_codigo, @fact_tipo, @fact_sucursal, @fact_numero
	END
	CLOSE PRODUCTO_CURSOR
	DEALLOCATE PRODUCTO_CURSOR
	/*
	-- Comentamos porque tenía problemas al agrupar, lo convertimos a cursor
	--INSERT Ventas --> (1)
	INSERT INTO Ventas (codigo_articulo, detalle, cant_mov, precio_venta, renglon, ganancia) --> (1)
		SELECT item_producto, prod_detalle, COUNT(*), AVG(item_precio) --,item_numero,(item_precio-item_cantidad*prod_precio) --> (2)
		FROM Factura f
		JOIN Item_factura i ON i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero
		JOIN Producto p ON p.prod_codigo=i.item_producto
		--WHERE fact_fecha BETWEEN @fecha_desde AND @fecha_hasta
		GROUP BY item_producto, prod_detalle --,item_numero,item_precio, item_cantidad, prod_precio --> (2)
	*/
END
*/

--------------------------------------------------------------------------------------------
--> Ejercicio (8)

DROP TABLE Diferencias

CREATE TABLE Diferencias(
	codigo CHAR(8),
	detalle CHAR(50),
	cantidad DECIMAL(12,2),
	precio_generado DECIMAL(12,2),
	precio_facturado DECIMAL(12,2),
);


DROP FUNCTION calcular_precio_producto
------------------------------------------------------------------------
SELECT comp_producto, COUNT(*) cant_componentes, SUM(comp_cantidad)
FROM Composicion c
GROUP BY comp_producto
ORDER BY 1

SELECT * FROM Composicion WHERE comp_producto='00001104'
------------------------------------------------------------------------

GO
CREATE FUNCTION calcular_precio_producto (@prod_codigo CHAR(8))
RETURNS DECIMAL(12,2)
AS
BEGIN
	DECLARE @RETORNO DECIMAL(12,2)
	DECLARE @componente CHAR(8), @componente_cantidad DECIMAL(12,2)

	--> Si el producto pasado por parámetro NO está compuesto por otros
	IF NOT EXISTS(SELECT 1 FROM Composicion WHERE comp_producto=@prod_codigo)
		BEGIN
			SET @RETORNO = (SELECT ISNULL(prod_precio, 0) FROM Producto WHERE prod_codigo=@prod_codigo)
			RETURN @RETORNO
		END
	--> Si el producto pasado por parámetro está compuesto por otros (Ej. un combo hamburguesa+papas+gaseosa)
	--> calculamos el precio de cada componente que componga al producto compuesto
	--> (el componente puede estar formado también por otros productos, y estos por otros, y asi..
	--> por eso necesitamos usar una función recursiva, no es suficiente solo con iterar sobre una variable especial del tipo CURSOR)
	ELSE
	BEGIN
		SET @RETORNO = 0 --> Inicializamos en 0, para que haga la sumatoria, porque puede tener un valor basura ej. 1203199318120

		DECLARE PRODUCTO_CURSOR CURSOR FOR
		SELECT comp_componente, comp_cantidad FROM Item_Factura i JOIN Composicion c ON c.comp_producto=i.item_producto
		OPEN PRODUCTO_CURSOR
		FETCH FROM PRODUCTO_CURSOR INTO @componente, @componente_cantidad
		WHILE @@FETCH_STATUS = 0
		BEGIN
			--> recursividad, se llama a la propia función para devolver el precio de un producto simple (entra por el IF),
			--> o el precio total de un componente que está formado por varios (entra por el ELSE)
			--
			--> 1. Por cada componente del producto, suma el precio del componente multiplicado por la cantidad que requiere de ese componente
			--> 2. Si es un producto simple (que no esta formado por otros) pasará por el IF y retornará su precio
			--> 3. Si es un producto compuesto, pasará por el ELSE y calculará los precios de sus componentes
			SET @RETORNO = @RETORNO + (dbo.calcular_precio_producto(@componente) * @componente_cantidad)

			FETCH FROM PRODUCTO_CURSOR INTO @componente, @componente_cantidad
		END
		CLOSE PRODUCTO_CURSOR
		DEALLOCATE PRODUCTO_CURSOR
	END

	RETURN @RETORNO
END
GO

--> Nota (1):
--> 1. Invocamos a una función recursiva para calcular el precio, porque un producto compuesto
--> puede estar formado por varios productos, y estos por otros, y estos por otros mas, y asi...
--> (similar a un árbol con varios niveles de profundidad, pero no dice que profundidad)
--
--> 2. Si usaramos sólo SUM() calculariamos el precio de las componentes del producto
--> pero sólo con un nivel de profundidad, en vez de los N niveles de profundidad que conforma al producto
--> (siendo N la cant. de componentes que son a su vez tambien productos compuestos por otros productos)
--> 
--> Nota (2):
--> 1. NO es necesario traer los productos de Composicion y JOINear con Producto
--> porque el SELECT asociado al CURSOR ya trae los productos vendidos que son compuestos
--
--> 2. NO es necesario agrupar, porque en el WHERE le estamos pasando prod_codigo que es la (PK) de la tabla Producto
-- y.. la (PK) garantiza la unicidad, de que NO se repetirán los registros
--
DROP PROCEDURE actualizar_diferencias

GO
CREATE PROCEDURE actualizar_diferencias
AS
BEGIN
	DECLARE @prod_cod CHAR(8), @precio_facturado DECIMAL(12,2)
	DECLARE @precio_componentes DECIMAL(12,2), @componente_cantidad INT
	DECLARE @cantidad_componentes DECIMAL(12,2)

	DECLARE PRODUCTO_CURSOR CURSOR FOR
	SELECT	comp_producto, item_precio, comp_cantidad
			FROM Item_Factura i										--> traeme todos los productos vendidos
			JOIN Composicion c ON c.comp_producto=i.item_producto	--> asociamos para que sean productos compuestos (formados por varios)
	OPEN PRODUCTO_CURSOR
	FETCH FROM PRODUCTO_CURSOR INTO @prod_cod, @precio_facturado, @componente_cantidad
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Si en vez de usar esta query, hacemos un JOIN en la query del INSERT
		-- deberiamos agrupar por todas las columnas, y.. habrian registros repetidos porque habrian mas combinaciones posibles
		SET @cantidad_componentes = (SELECT COUNT(*) FROM Composicion WHERE comp_producto=@prod_cod) --> (3)

		--> puede parecer que luego del INSERT parezca que hay registros repetidos, pero es porque cada producto se pudo vender a diferentes precios
		INSERT INTO Diferencias (codigo, detalle, cantidad, precio_facturado, precio_generado)
			SELECT	prod_codigo, prod_detalle, @cantidad_componentes,
					@precio_facturado, dbo.calcular_precio_producto(prod_codigo) --> (1)
					--SUM(ISNULL(prod_precio, 0)) --> (1)
			FROM Producto
			WHERE prod_codigo=@prod_cod
			--FROM Composicion c JOIN Producto p ON p.prod_codigo=c.comp_componente	--> (2)
			--WHERE c.comp_producto=@prod_cod										--> (2)
			--GROUP BY p.prod_codigo, p.prod_detalle								--> (2)

		FETCH FROM PRODUCTO_CURSOR INTO @prod_cod, @precio_facturado, @componente_cantidad
	END
	CLOSE PRODUCTO_CURSOR
	DEALLOCATE PRODUCTO_CURSOR
END

----------------------------------------------------------------------------------------------------------------
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
-- probamos la función con productos que están compuestos por otros
SELECT comp_producto, COUNT(*) veces_comprado ,dbo.calcular_precio_producto(comp_producto) precio
FROM Item_Factura i
JOIN Composicion c ON c.comp_producto=i.item_producto
GROUP BY comp_producto
HAVING COUNT(*) < 30

-- probamos la función con productos que sabemos que no son compuestos por otros
SELECT item_producto, COUNT(*) veces_comprado ,dbo.calcular_precio_producto(item_producto) precio
FROM Item_Factura i
WHERE item_producto NOT IN (SELECT comp_producto FROM Composicion)
GROUP BY item_producto

BEGIN TRAN
EXEC actualizar_diferencias
SELECT * FROM Diferencias ORDER BY codigo
ROLLBACK
----------------------------------------------------------------------------------------------------------------
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
	/*
	SELECT	comp_producto, prod_detalle, COUNT(*) cant_componentes
			--,item_precio*item_cantidad precio_facturado
			--,(SELECT SUM(prod_precio) FROM Producto WHERE prod_codigo=c.comp_componente) precio_generado
	FROM Item_Factura i
	JOIN Composicion c ON c.comp_producto=i.item_producto	--> para obtener datos de los componentes
	JOIN Producto p ON p.prod_codigo=i.item_producto		--> para obtener datos del producto (precio,detalle,..)
	GROUP BY comp_producto, prod_detalle, item_precio --, item_cantidad
	ORDER BY 1
	*/
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------

--> Ejercicio (9)
--
-- (???)

--------------------------------------------------------------------------------------------
--> Ejercicio (10)

GO
CREATE TRIGGER audit_borrar_articulo ON Producto
INSTEAD OF DELETE
AS
BEGIN
	DECLARE @producto CHAR(8)

	DECLARE ITEM_CURSOR CURSOR FOR
	SELECT prod_codigo FROM deleted
	OPEN ITEM_CURSOR
	FETCH FROM ITEM_CURSOR INTO @producto
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF EXISTS(SELECT 1 FROM STOCK WHERE stoc_producto=@producto HAVING SUM(stoc_cantidad) > 0)
			DELETE FROM Producto WHERE prod_codigo=@producto
		--IF (SELECT SUM(stoc_cantidad) FROM STOCK WHERE stoc_producto=@producto) > 0 <--- OTRA ALTERNATIVA
		--	DELETE FROM Producto WHERE prod_codigo=@producto
		ELSE
			PRINT 'Error..! NO hay stock suficiente' --> (1)
			--> Si usamos el RAISERROR() podriamos llegar a cortar el fujo del iterar sobre los DELETE
			--> porque un TRIGGER puede recibir varios eventos DELETE,
			--> por tanto, si se corta el flujo, habrian varios DELETE que no controlariamos si hay stock

		FETCH FROM ITEM_CURSOR INTO @producto
	END
	CLOSE ITEM_CURSOR
	DEALLOCATE ITEM_CURSOR
END

---------------------------------------------------------------------------------------------------------------------------------
--> probamos dos alternativas para evaluar condiciones
--
		DECLARE @producto_mayor_stock CHAR(8), @producto_sin_stock CHAR(8)
		SET @producto_mayor_stock=(SELECT TOP 1 stoc_producto FROM STOCK GROUP BY stoc_producto ORDER BY SUM(stoc_cantidad) DESC)
		SET @producto_sin_stock=(SELECT TOP 1 stoc_producto FROM STOCK GROUP BY stoc_producto HAVING SUM(stoc_cantidad) = 0)
		--SELECT @producto_mayor_stock, @producto_sin_stock

		-- Alternativa #A
		--> 1. Evaluamos usando si existe algun registro que cumpla la condición
		--> 2. Usamos IF EXISTS + HAVING
		--> 3. No necesitamos devolver algun dato columna, por eso devolvemos un 1 en el SELECT
		IF EXISTS(SELECT 1 FROM STOCK WHERE stoc_producto=@producto_mayor_stock HAVING SUM(stoc_cantidad) > 0)
			PRINT 'opcion a) hay stock del producto ' + @producto_mayor_stock
		IF EXISTS(SELECT 1 FROM STOCK WHERE stoc_producto=@producto_sin_stock HAVING SUM(stoc_cantidad) = 0)
			PRINT 'opcion a) no hay stock del producto ' + @producto_sin_stock

		-- Alternativa #B
		--> 1. Evaluamos la cant. de registros que cumplan la condición
		--> 2. Usamos IF + SELECT Función de Agregación
		--> 3. Devolvemos la cantidad en el SELECT para comparar con un valor en el IF
		IF( (SELECT SUM(stoc_cantidad) FROM STOCK WHERE stoc_producto=@producto_mayor_stock) > 0)
			PRINT 'opcion b) hay stock del producto ' + @producto_mayor_stock

		IF( (SELECT SUM(stoc_cantidad) FROM STOCK WHERE stoc_producto=@producto_sin_stock) = 0)
			PRINT 'opcion b) no hay stock del producto ' + @producto_sin_stock
---------------------------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
--> Ejercicio (11)

DROP FUNCTION calcular_cantidad_empleados_a_cargo

GO
CREATE FUNCTION calcular_cantidad_empleados_a_cargo (@empl_jefe NUMERIC(6))
RETURNS INT
AS
BEGIN
	DECLARE @RETORNO INT, @empl_codigo NUMERIC(6)

	--> Caso No recursivo
	--> Si no existe ningun jefe con el codigo de empleado pasado por parámetro,
	--> devolvemos 0 porque éste al no ser jefe no tendrá otros empleados asociados a él como subordinados
	IF NOT EXISTS(SELECT 1 FROM Empleado WHERE empl_jefe=@empl_jefe)
	BEGIN
		SET @RETORNO = 0
		RETURN @RETORNO
	END
	--> Si existe algun jefe con el codigo de empleado pasado por parametro
	ELSE
	BEGIN
		--> contamos la cant. de empleados que tenga a cargo directamente (están asociados a él como subordinados)
		SET @RETORNO = (SELECT COUNT(*) FROM Empleado WHERE empl_jefe=@empl_jefe)

		--> 1. iteramos sobre cada empleado que tenga a cargo ese jefe (sobre una variable especial que es tipo CURSOR)
		--> y vamos a chequear si alguno de ellos también es jefe de otros empleados, y si estos otros tmb lo son de otros más, ...)
		--> 2. Si se cumple esto segundo, estos seran empleados indirectamente, porque son subordinados de un empleado
		--> (Ej. Gerente General, Gerente de Ventas, Subgerente de ventas, vendedorA, vendedorB, ...)
		DECLARE EMPLEADO_CURSOR CURSOR FOR
		SELECT empl_codigo FROM Empleado WHERE empl_jefe=@empl_jefe
		OPEN EMPLEADO_CURSOR
		FETCH FROM EMPLEADO_CURSOR INTO @empl_codigo
		WHILE @@FETCH_STATUS = 0
		BEGIN
			--> 3.1 Si alguno de los empleados es jefe de otros => pasará por el ELSE, y los contará con el (SELECT COUNT(*) ...)
			-->	3.2 Pasará por este CURSOR y evaluará cada empleado que tenga a cargo cada empleado jefe
			--> Ej. Jefe -> empleado,empleado,jefe,jefe
			--		Jefe -> empleado, empleado, jefe->(empleado, empleado, jefe), jefe->(empleado, empleado)
			--		Jefe -> empleado, empleado, jefe->(empleado, empleado, jefe->(empleado, empleado)), jefe->(empleado, empleado)
			--		
			--> 2.	Si alguno de los empleados NO es jefe => pasará sólo por el IF que retorna 0 porque no tiene empleados a cargo al no ser jefe
			SET @RETORNO = @RETORNO + dbo.calcular_cantidad_empleados_a_cargo(@empl_codigo)

			FETCH FROM EMPLEADO_CURSOR INTO @empl_codigo
		END
		CLOSE EMPLEADO_CURSOR
		DEALLOCATE EMPLEADO_CURSOR
	END

	RETURN @RETORNO
END

----------------------------------------------------------------------------------------------------------------
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
	/*
	-- probamos con el empl_jefe=1 que es jefe de todos
	SELECT dbo.calcular_cantidad_empleados_a_cargo(1)
	-- probamos quien es jefe de quien
	SELECT empl_jefe, empl_codigo FROM Empleado ORDER BY 1

	SELECT empl_codigo, dbo.calcular_cantidad_empleados_a_cargo(empl_codigo) cant_empleados_a_cargo
	FROM Empleado
	GROUP BY empl_codigo
	*/
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
--> Ejercicio (12)
--
--> Nota (1):
--> Capturamos los eventos INSERT/UPDATE
--> 1. Para los UPDATE usaremos las tablas lógicas inserted/deleted
--> 2. Para los INSERT usaremos la tabla lógica inserted
--
--> I M P O R T A N T E..!: <-----
-->
--> Para emular la acción del evento UPDATE debemos hacer al mismo tiempo DELETE+INSERT
--> 1. DELETE: Borrar los registros con los datos viejos
--> 2. INSERT: Insertar los registros con los datos nuevos
GO
CREATE TRIGGER audit_producto_composicion ON Composicion
INSTEAD OF INSERT, UPDATE AS --> (1)
BEGIN
	-- Evaluamos el caso de uno o varios INSERT
	-- 1. chequeamos si no hizo UPDATE (porque deleted contiene los valores anteriores al update)
	-- 2. usamos la función de agregación COUNT(*) de la tabla lógica DELETED porque pueden ser uno o más registros
	IF ((SELECT COUNT(*) FROM deleted) = 0)
		-- 2.1 validamos si los registros a insertar algún producto está compuesto por si mismo (con la función recursiva)
		-- la función devuelve 1 si alguno está compuesto por si mismo, evaluamos si ocurre con más de un registro
		IF ( (SELECT COUNT(*) FROM inserted WHERE dbo.validar_composicion(comp_producto, comp_componente) = 1) > 0)
			PRINT 'Error, un producto NO puede estar compuesto por si mismo'
		ELSE
		-- 2.2 Si ningún producto a insertar está compuesto consigo mismo, insertamos todos los registros
			INSERT INTO Composicion 
			SELECT * FROM inserted WHERE dbo.validar_composicion(comp_producto, comp_componente) = 0

	-- Evaluamos el caso de uno o varios UPDATE (inserted+deleted)
	BEGIN
		DECLARE @comp_producto_old CHAR(8), @comp_componente_old CHAR(8)	--> para la tabla DELETED
		DECLARE @comp_producto_nuevo CHAR(8), @comp_componente_nuevo CHAR(8)--> para la tabla INSERTED
		DECLARE @comp_cantidad DECIMAL(12,2)

		-- Solo declaramos los dos cursores, y le asociamos su query
		-- (Un cursor es un tipo de variable especial que almacena un cjto de registros de un SELECT, y se puede iterar)
		DECLARE PRODUCTO_OLD_CURSOR CURSOR FOR
			SELECT comp_producto, comp_componente FROM deleted
		DECLARE PRODUCTO_NUEVO_CURSOR CURSOR FOR
			SELECT comp_producto, comp_componente, comp_cantidad FROM inserted

		OPEN PRODUCTO_OLD_CURSOR
		OPEN PRODUCTO_NUEVO_CURSOR

		-- leemos el primer registro de cada cursor por separado, y guardamos los datos en las variables con @
		FETCH FROM PRODUCTO_OLD_CURSOR INTO @comp_producto_old, @comp_componente_old
		FETCH FROM PRODUCTO_NUEVO_CURSOR INTO @comp_producto_nuevo, @comp_componente_nuevo, @comp_cantidad

		-- recorremos ambos cursores en simultaneo
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- ...
			IF(dbo.validar_composicion(@comp_producto_nuevo, @comp_componente_nuevo) = 1)
				PRINT 'Error, un producto NO puede estar compuesto por si mismo'
			ELSE
				-- si replicamos lo que hace el UPDATE => entonces hacemos un 1) DELETE (datos viejos) --> 2) INSERT (datos nuevos)
				BEGIN
					-- borramos el registro anterior
					DELETE FROM Composicion WHERE comp_producto=@comp_producto_old AND comp_componente=@comp_componente_old
					-- insertamos el registro anterior con los datos nuevos
					INSERT INTO Composicion (comp_producto, comp_componente, comp_cantidad) VALUES (@comp_producto_nuevo , @comp_componente_nuevo, @comp_cantidad)
				END				

			-- avanzamos ambos cursores en simultaneo, necesario para simular la acción de un update (hace delete y luego insert)
			FETCH FROM PRODUCTO_OLD_CURSOR INTO @comp_producto_old, @comp_componente_old
			FETCH FROM PRODUCTO_NUEVO_CURSOR INTO @comp_producto_nuevo, @comp_componente_nuevo, @comp_cantidad
		END

		CLOSE PRODUCTO_OLD_CURSOR
		DEALLOCATE PRODUCTO_OLD_CURSOR

		CLOSE PRODUCTO_NUEVO_CURSOR
		DEALLOCATE PRODUCTO_NUEVO_CURSOR
	END
END

----------------------------------------------------------------------------------------------------------------
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
	/*
	SELECT comp_producto, comp_componente --,dbo.validar_composicion(comp_producto, comp_componente) validado
	FROM Composicion
	GROUP BY comp_producto, comp_componente
	ORDER BY comp_producto, comp_componente
	*/
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

DROP FUNCTION validar_composicion

GO
CREATE FUNCTION validar_composicion (@comp_producto CHAR(8), @comp_componente CHAR(8))
RETURNS INT --> Devolvemos INT, pero lo usaremos como si fuese un boolean true/false
AS
BEGIN
	DECLARE @RETORNO INT
	DECLARE @componente CHAR(8)	

	IF (@comp_producto = @comp_componente)
		BEGIN
			SET @RETORNO = 1
			RETURN @RETORNO --> cortamos el flujo
		END
	ELSE
	BEGIN
		--> como de entrada no son iguales, probamos otras combinaciones, comparando con los demás componentes
		--> pero arrancamos con 0, hasta que alguna comparación demuestre lo contrario
		SET @RETORNO = 0

		--> 1. Usaremos una variable especial tipo CURSOR, a la que vamos asignarle un conjunto de registros con un SELECT
		--> 2. Iteraremos la variable CURSOR para validar si un componente B que conforma al producto A, está conformados por otros C,D,..
		--> y uno de esos C,D,.. es el producto A (para saber si otro producto está compuesto por él)
		DECLARE PRODUCTO_CURSOR CURSOR FOR
			SELECT comp_componente FROM Composicion WHERE comp_producto=@comp_producto
		OPEN PRODUCTO_CURSOR
		FETCH FROM PRODUCTO_CURSOR INTO @componente
		WHILE @@FETCH_STATUS = 0
		BEGIN
			--> si no se cumple el condicional, sigue iterando por cada registro (producto,componente)
			IF(dbo.validar_composicion(@comp_producto, @componente) = 1)
			BEGIN
				SET @RETORNO = 1
				RETURN @RETORNO --> cortamos el flujo de la función, así no tiene que seguir iterando y evaluando
			END
				
			FETCH FROM PRODUCTO_CURSOR INTO @componente
		END
		CLOSE PRODUCTO_CURSOR
		DEALLOCATE PRODUCTO_CURSOR
	END

	RETURN @RETORNO
END

----------------------------------------------------------------------------------------------------------------
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
	/*
	--> 1. Haciendo algunas pruebas con los triggers, y los cursores
	--> 2. Recorremos dos cursores al mismo tiempo
	--> 3. Si hubieramos hecho otro (WHILE @@FETCH_STATUS = 0) estariamos anidando cursores
	DROP TRIGGER audit_test

	GO
	--> El UPDATE captura las tablas logicas inserted/deleted
	--> El INSERT captura los registros de inserted
	CREATE TRIGGER audit_test ON copia_Composicion
	INSTEAD OF INSERT, UPDATE AS
	BEGIN
		IF ((SELECT COUNT(*) FROM deleted) > 0)
			PRINT 'estas borrando...'
		ELSE
			PRINT 'estas insertando...'

		--------------------------------------------------------

		DECLARE @producto_del CHAR(8), @componente_del CHAR(8)
		DECLARE @producto_ins CHAR(8), @componente_ins CHAR(8)

		DECLARE PRODUCTO_DELETED_CURSOR CURSOR FOR
			SELECT comp_producto, comp_componente FROM deleted
		DECLARE PRODUCTO_INSERTED_CURSOR CURSOR FOR
			SELECT comp_producto, comp_componente FROM inserted

		OPEN PRODUCTO_DELETED_CURSOR
		OPEN PRODUCTO_INSERTED_CURSOR

		FETCH FROM PRODUCTO_DELETED_CURSOR INTO @producto_del, @componente_del
		FETCH FROM PRODUCTO_INSERTED_CURSOR INTO @producto_ins, @componente_ins
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- ...
			PRINT 'estas borrando... prod='+@producto_del+' comp='+@componente_del
			PRINT 'estas insertando... prod='+@producto_ins+' comp='+@componente_ins

			FETCH FROM PRODUCTO_DELETED_CURSOR INTO @producto_del, @componente_del
			FETCH FROM PRODUCTO_INSERTED_CURSOR INTO @producto_ins, @componente_ins
			-- ...
		END
		CLOSE PRODUCTO_DELETED_CURSOR
		DEALLOCATE PRODUCTO_DELETED_CURSOR

		CLOSE PRODUCTO_INSERTED_CURSOR
		DEALLOCATE PRODUCTO_INSERTED_CURSOR
	END

	--> hacemos una copia de la tabla, para evitar futuros problemas..
	SELECT * INTO copia_Composicion FROM Composicion --> Crea la tabla e inserta
	INSERT INTO copia_Composicion SELECT * FROM Composicion --> Inserta en una tabla existente

	BEGIN TRAN
	--SELECT * FROM copia_Composicion
	INSERT INTO copia_Composicion (comp_cantidad, comp_producto, comp_componente)
	VALUES	(1, '20000000', '30000000'), (1, '20000000', '30000001'), (1, '20000000', '30000002'),
			(2, '20000001', '30000000'), (2, '20000001', '30000001'), (2, '20000001', '30000002'),
			(3, '20000002', '30000000'), (4, '20000002', '30000001'), (4, '20000002', '30000002')

	--> con esto validamos que el trigger..
	--> La tabla lógica "deleted" contiene los datos a borrar
	DELETE FROM copia_Composicion

	--> con esto validamos que el trigger..
	--> La tabla lógica "deleted" contiene los datos previos al update (viejos)
	--> La tabla lógica "inserted" contiene los datos luego al update (nuevos)
	UPDATE copia_Composicion SET comp_cantidad=0
	*/
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
--> Ejercicio (13)

DROP TRIGGER audit_salario_jefes_v1

-- Alternativa #1
GO
CREATE TRIGGER audit_salario_jefes_v1 ON Empleado
AFTER UPDATE AS --> (1)
BEGIN
	IF EXISTS( SELECT 1 FROM inserted 
				WHERE empl_salario > dbo.salario_empleados_directos_indirectos_de_v1(empl_codigo)*0.2
				)
		ROLLBACK TRAN
END
GO

-- Alternativa #2 - Cursor "SE PUEDE EVITAR"
--
--> Nota (1):
--> 1. NO es necesario evaluar el escenario del evento INSERT, 
--> porque si se inserta un jefe, previamente un empleado lo deberia tener asociado como jefe
--
--> 2. Pero SI es necesario el UPDATE, porque puede llegar a cambiar al jefe, o los salarios
--> o la cant. de empleados asignados, etc..
--
--> Nota (3):
--> NO estas evaluando cada caso por separado, estás metiendo todos en una bolsa..

DROP TRIGGER audit_salario_jefes_v2

GO
CREATE TRIGGER audit_salario_jefes_v2 ON Empleado
AFTER UPDATE AS --> (1)
BEGIN
	--IF( (SELECT COUNT(*) FROM inserted WHERE validar_salario_jefe(empl_jefe)) > 0 ) --> (1)
	--	PRINT 'El jefe NO puede superar el 20% de salario que sus empleados'
	DECLARE @empl_cod CHAR(8), @empl_salario DECIMAL(12,2)

	DECLARE EMPLEADO_CURSOR CURSOR FOR
		SELECT empl_codigo, empl_salario FROM inserted
	OPEN EMPLEADO_CURSOR
	FETCH FROM EMPLEADO_CURSOR INTO @empl_cod, @empl_salario
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF(@empl_salario > dbo.salario_empleados_directos_indirectos_de_v1(@empl_cod)*0.2)
			ROLLBACK TRANSACTION

		FETCH FROM EMPLEADO_CURSOR INTO @empl_cod, @empl_salario
	END
	CLOSE EMPLEADO_CURSOR
	DEALLOCATE EMPLEADO_CURSOR
END


-- Alternativa #1 - Definimos la función recursiva
DROP FUNCTION salario_empleados_directos_indirectos_de_v1

GO
CREATE FUNCTION salario_empleados_directos_indirectos_de_v1(@jefe CHAR(8))
RETURNS INT AS
BEGIN
	DECLARE @salario_empleados INT

	IF NOT EXISTS(SELECT 1 FROM Empleado WHERE empl_jefe=@jefe)
		RETURN 0 --> cortamos el flujo de la recursividad
	ELSE
		SET @salario_empleados = (SELECT SUM(empl_salario)+SUM(dbo.salario_empleados_directos_indirectos_de_v1(empl_codigo))
									FROM Empleado WHERE empl_jefe=@jefe) 
	
	/*
	-- lo separamos para ver que sucede en la query anterior
	--
	--> 1. Sumamos los salarios de los empleados directos al jefe
	SET @salario_empleados = (SELECT SUM(empl_salario) FROM Empleado WHERE empl_jefe=@jefe) 
	--> 2. Sumamos los salarios de los empleados indirectos al jefe, porque alguno de sus empleados es jefe y tiene a cargo otros empleados
	SET @salario_empleados = @salario_empleados + (SELECT SUM(dbo.salario_empleados_directos_indirectos_de_v1(empl_codigo)) FROM Empleado WHERE empl_jefe=@jefe)
	*/

	RETURN @salario_empleados
END
GO

-- Alternativa #2 - Probamos con cursores
DROP FUNCTION salario_empleados_directos_indirectos_de_v2
GO
CREATE FUNCTION salario_empleados_directos_indirectos_de_v2(@jefe CHAR(8))
RETURNS INT AS
BEGIN
	DECLARE @empleado CHAR(8), @salario_empleados INT

	-- caso base
	IF NOT EXISTS(SELECT 1 FROM Empleado WHERE empl_jefe=@jefe)
		RETURN 0

	SET @salario_empleados = (SELECT SUM(ISNULL(empl_salario, 0)) FROM Empleado WHERE empl_jefe=@jefe)

	DECLARE EMPLEADO_CURSOR CURSOR FOR
	SELECT empl_codigo FROM Empleado WHERE empl_jefe=@jefe
	OPEN EMPLEADO_CURSOR
	FETCH FROM EMPLEADO_CURSOR INTO @empleado
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @salario_empleados = @salario_empleados + dbo.salario_empleados_directos_indirectos_de_v2(@empleado)

		FETCH FROM EMPLEADO_CURSOR INTO @empleado
	END
	CLOSE EMPLEADO_CURSOR
	DEALLOCATE EMPLEADO_CURSOR

	RETURN @salario_empleados	
END

----------------------------------------------------------------------------------------------------------------
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
	/*
	SELECT	empl_codigo,
			dbo.salario_empleados_directos_indirectos_de_v1(empl_codigo) salario_empleados1,
			dbo.salario_empleados_directos_indirectos_de_v2(empl_codigo) salario_empleados2
	FROM Empleado
	GROUP BY empl_codigo
	*/
------------------------------------------ PROBANDO QUERY	------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
--> Ejercicio (14)

DROP TRIGGER audit_compras_clientes_v1

-- Alternativa #1 con "AFTER INSERT"
GO
CREATE TRIGGER audit_compras_clientes_v1 ON Factura
AFTER INSERT AS
BEGIN
	DECLARE @producto CHAR(8), @precio DECIMAL(12,2), @precio_componentes DECIMAL(12,2)
	DECLARE @cliente CHAR(6), @fecha SMALLDATETIME

	DECLARE FACTURA_CURSOR CURSOR FOR
		SELECT item_producto, item_precio, fact_cliente, fact_fecha FROM inserted f
		JOIN Item_Factura i ON i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero
	OPEN FACTURA_CURSOR
	FETCH FROM FACTURA_CURSOR INTO @producto, @precio, @cliente, @fecha
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- ....
		SET @precio_componentes = (SELECT SUM(prod_precio) FROM Composicion c JOIN Producto p ON p.prod_codigo=c.comp_componente WHERE c.comp_producto=@producto)

		IF(	@precio < @precio_componentes)
			PRINT @fecha + ', ' + @cliente + ', ' + @precio

		IF (@precio < @precio_componentes*0.5)
			ROLLBACK TRANSACTION

		FETCH FROM FACTURA_CURSOR INTO @producto, @precio, @cliente, @fecha
	END
	CLOSE FACTURA_CURSOR
	DEALLOCATE FACTURA_CURSOR

END
GO

-- Alternativa #2 con "INSTEAD OF INSERT" --------------------------------------------------------> pendiente


-- Comentamos esta alternativa, porque me parece que dos cursores no seran necesarios
/*
GO
CREATE TRIGGER audit_compras_clientes_v2 ON Factura
AFTER INSERT AS
BEGIN
	DECLARE @fact_tipo CHAR(1), @fact_sucursal CHAR(4), @fact_numero CHAR(8)
	DECLARE @producto CHAR(8), @precio DECIMAL(12,2), @precio_componentes DECIMAL(12,2)

	DECLARE FACTURA_CURSOR CURSOR FOR
		SELECT fact_tipo, fact_sucursal, fact_numero, fact_cliente FROM inserted
	OPEN FACTURA_CURSOR
	FETCH FROM FACTURA_CURSOR INTO @fact_tipo, @fact_sucursal, @fact_numero, @cliente
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- ...
		DECLARE ITEM_FACTURA_CURSOR CURSOR FOR
		SELECT item_producto, item_precio FROM Item_Factura i 
			WHERE i.item_tipo=@fact_tipo AND i.item_sucursal=@fact_sucursal AND i.item_numero=@fact_numero
		OPEN ITEM_FACTURA_CURSOR
		FETCH FROM ITEM_FACTURA_CURSOR INTO @producto, @precio
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- ....
			SET @precio_componentes = (SELECT SUM(prod_precio)*0.5 FROM Composicion c JOIN Producto p ON p.prod_codigo=c.comp_producto WHERE comp_producto=@producto GROUP BY comp_producto)

			IF( @precio  < @precio_componentes)
				PRINT @fecha + ', ' + @cliente + ', ' + @precio

			IF( @precio  < @precio_componentes*0.5)
				ROLLBACK

			FETCH FROM ITEM_FACTURA_CURSOR INTO @producto, @precio
		END
		CLOSE ITEM_FACTURA_CURSOR
		DEALLOCATE ITEM_FACTURA_CURSOR

		FETCH FROM FACTURA_CURSOR INTO @fact_tipo, @fact_sucursal, @fact_numero 
	END
	CLOSE FACTURA_CURSOR
	DEALLOCATE FACTURA_CURSOR
END
*/

/*
SELECT c.comp_producto, COUNT(distinct comp_componente), COUNT(*)
FROM Factura f
JOIN Item_Factura i ON i.item_tipo=f.fact_tipo AND i.item_sucursal=f.fact_sucursal AND i.item_numero=f.fact_numero
JOIN Composicion c ON i.item_producto=i.item_producto
GROUP BY c.comp_producto
*/


--------------------------------------------------------------------------------------------
--> Ejercicio (15)

DROP FUNCTION calcular_precio_producto 

GO
CREATE FUNCTION calcular_precio_producto (@producto_id CHAR(8))
RETURNS DECIMAL(12,2) AS
BEGIN
	DECLARE @RETORNO DECIMAL(12,2)

	-- CASO BASE
	IF EXISTS (SELECT 1 FROM Composicion WHERE comp_componente=@producto_id)
		RETURN (SELECT prod_precio FROM Producto WHERE prod_codigo=@producto_id)
		--RETURN 0

	-- CASO RECURSIVO
	--SET @RETORNO = (SELECT SUM(prod_precio) FROM Composicion c JOIN Producto p ON p.prod_codigo=c.comp_producto WHERE comp_producto=@producto_id) +
	--				(SELECT SUM(dbo.calcular_precio_producto(comp_componente)*comp_cantidad) FROM Composicion WHERE comp_producto=@producto_id)
	
	SET @RETORNO = (SELECT SUM(dbo.calcular_precio_producto(comp_componente)*comp_cantidad) FROM Composicion WHERE comp_producto=@producto_id)

	RETURN @RETORNO
END

-- probamos la función dentro de una query
SELECT comp_producto, dbo.calcular_precio_producto(comp_producto)  FROM Composicion



--------------------------------------------------------------------------------------------
--> Ejercicio (16)

DROP TRIGGER actualizar_stock_segun_ventas 

GO
CREATE TRIGGER actualizar_stock_segun_ventas ON Item_Factura
AFTER INSERT AS
BEGIN
	DECLARE @producto_id CHAR(8), @producto_cantidad DECIMAL(12,2)
	DECLARE @stoc_deposito CHAR(2), @stoc_cantidad DECIMAL(12,2)

	DECLARE ITEM_VENDIDO_CURSOR CURSOR FOR
	SELECT item_producto, item_cantidad FROM inserted
	OPEN ITEM_VENDIDO_CURSOR 
	FETCH FROM ITEM_VENDIDO_CURSOR INTO @producto_id, @producto_cantidad
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- ...
		DECLARE STOCK_DEPOSITO_CURSOR CURSOR FOR
		SELECT stoc_deposito, stoc_cantidad FROM STOCK WHERE stoc_producto=@producto_id ORDER BY stoc_cantidad DESC
		OPEN STOCK_DEPOSITO_CURSOR
		FETCH FROM STOCK_DEPOSITO_CURSOR INTO @stoc_deposito, @stoc_cantidad
		WHILE @stoc_cantidad > 0 AND @@FETCH_STATUS = 0 --> (1) Don't forget el FETCH_STATUS
		BEGIN
			-- ...
			IF( @producto_cantidad <= @stoc_cantidad )
				BEGIN
					UPDATE STOCK
						SET stoc_cantidad = stoc_cantidad - @producto_cantidad
						WHERE stoc_deposito=@stoc_deposito AND stoc_producto=@producto_id

						--> si no lo modificamos el CURSOR no lo hará,
						--> porque queda con el valor inicial
						SET @stoc_cantidad = @stoc_cantidad - @producto_cantidad
				END
			ELSE
				BEGIN
					UPDATE STOCK
						SET stoc_cantidad = 0
						WHERE stoc_deposito=@stoc_deposito AND stoc_producto=@producto_id

					--> para cortar el flujo
					SET @producto_cantidad = 0
				END

			FETCH FROM STOCK_DEPOSITO_CURSOR INTO @stoc_deposito, @stoc_cantidad
		END
		CLOSE STOCK_DEPOSITO_CURSOR
		DEALLOCATE STOCK_DEPOSITO_CURSOR

		--> 1. El enunciado pide que el ultimo depósito quede con valor negativo
		--> 2. Las variable @stoc_deposito queda con el valor del ultimo deposito insertado en el cursor
		IF ( @producto_cantidad > 0 )
			UPDATE STOCK
				SET stoc_cantidad = stoc_cantidad - @producto_cantidad
				WHERE stoc_deposito=@stoc_deposito AND stoc_producto=@producto_id

		FETCH FROM ITEM_VENDIDO_CURSOR INTO @producto_id, @producto_cantidad
	END
	CLOSE ITEM_VENDIDO_CURSOR 
	DEALLOCATE ITEM_VENDIDO_CURSOR 

END


--------------------------------------------------------------------------------------------
--> Ejercicio (17) -> "pendiente a chequear"

DROP TRIGGER validar_movimientos_stock

GO
CREATE TRIGGER validar_movimientos_stock ON STOCK
AFTER INSERT as
BEGIN
	-- ... INSERT
	DECLARE @stock_max DECIMAL(12,2), @stock_min DECIMAL(12,2), @stock_cantidad DECIMAL(12,2)

	DECLARE @stock_deposito CHAR(2), @stock_producto CHAR(8)

	DECLARE STOCK_CURSOR CURSOR FOR
		SELECT stoc_deposito, stoc_producto FROM inserted
	OPEN STOCK_CURSOR
	FETCH FROM STOCK_CURSOR INTO @stock_deposito, @stock_producto
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @stock_max=stoc_stock_maximo, @stock_min=stoc_punto_reposicion, @stock_cantidad=stoc_cantidad
			FROM STOCK WHERE stoc_deposito=@stock_deposito AND stoc_producto=@stock_producto

		IF (@stock_cantidad > @stock_max OR @stock_cantidad < @stock_min)
			ROLLBACK TRANSACTION

		FETCH FROM STOCK_CURSOR INTO @stock_deposito, @stock_producto
	END
	CLOSE STOCK_CURSOR
	DEALLOCATE STOCK_CURSOR
END
GO


--------------------------------------------------------------------------------------------
--> Ejercicio (18)
-- Alternativa #1 - Con "AFTER INSERT"
DROP TRIGGER audit_facturacion_clientes_v1 

GO
CREATE TRIGGER audit_facturacion_clientes_v1 ON Factura
AFTER INSERT AS
BEGIN
	-- ...
	IF EXISTS(	SELECT 1 FROM inserted i
				JOIN Cliente c ON c.clie_codigo=i.fact_cliente
				WHERE clie_limite_credito < i.fact_total+(SELECT SUM(fact_total) FROM Factura
															WHERE fact_cliente=c.clie_codigo AND
															MONTH(fact_fecha)=MONTH(i.fact_fecha) AND YEAR(fact_fecha)=YEAR(i.fact_fecha) )
				)
				BEGIN
					RAISERROR('NO el cliente NO puede superar su credito mensual', 16, 1)
					ROLLBACK
				END
	-- ...
END
GO
/*
-- probamos con un cliente que ya sabemos que NO puede superar su credito mensual
BEGIN TRAN
INSERT INTO Factura (fact_tipo, fact_sucursal, fact_numero, fact_fecha, fact_vendedor, fact_total, fact_total_impuestos, fact_cliente)
	SELECT 'B', fact_sucursal, fact_numero, fact_fecha, fact_vendedor, fact_total, fact_total_impuestos, fact_cliente
	FROM Factura WHERE YEAR(fact_fecha)=2012  AND MONTH(fact_fecha)=1 AND fact_cliente='00656'
*/
/*
-- chequeamos que cliente NO puede superar su credito mensual
SELECT TOP 1 clie_codigo, clie_limite_credito, MONTH(fact_fecha), YEAR(fact_fecha),
		(SELECT SUM(fact_total) FROM Factura WHERE fact_cliente=c.clie_codigo AND
		MONTH(fact_fecha)=MONTH(f.fact_fecha) AND YEAR(fact_fecha)=YEAR(f.fact_fecha)) fact_total
FROM Factura f
JOIN Cliente c ON c.clie_codigo=f.fact_cliente
WHERE clie_limite_credito < f.fact_total+(	SELECT SUM(fact_total) FROM Factura WHERE fact_cliente=c.clie_codigo AND
											MONTH(fact_fecha)=MONTH(f.fact_fecha) AND YEAR(fact_fecha)=YEAR(f.fact_fecha) )
GROUP BY clie_codigo, clie_limite_credito, MONTH(fact_fecha), YEAR(fact_fecha)
ORDER BY 1
*/
-- Alternativa #1 - Con "INSTEAD OF INSERT"
GO
CREATE TRIGGER audit_facturacion_clientes_v2 ON Factura
INSTEAD OF INSERT AS
BEGIN
	-- ...
	--> Hubiese sido casi igual que el AFTER INSERT, 
	--> 1. Si no superaba el limite de credito mensual => INSERT
	-- ...
END
GO








