-----------------------------------------------------------------------------------------------
-- preparamos las tablas, para utilizar con los ejs de triggers
SELECT * FROM products;

DROP TABLE productos_premium

SELECT stock_num, unit_code, unit_price, manu_code INTO productos_premium FROM products

SELECT * FROM productos_premium;

DROP TABLE estado_auditoria;

CREATE TABLE estado_auditoria(
	cod_auditoria	INT	IDENTITY (1,1),
	cod_producto SMALLINT,
	usuario VARCHAR(20),
	accion CHAR,
	fechaHora datetime
);

SELECT * FROM estado_auditoria;
GO
------------------------------------------------------------------------------------------------
-- TRIGGER CON "AFTER UPDATE"

DROP TRIGGER actualizarEstadoAuditoria;
-- por cada registro actualizado:
-- 1. se insertará un registro con los datos previo al update
-- 2. se insertará otro registro con los datos luego de update
-- por tanto se insertaran dos registros por cada registro que se aplique update
CREATE TRIGGER actualizarEstadoAuditoria ON productos_premium
AFTER UPDATE
AS
BEGIN
	INSERT INTO estado_auditoria
	SELECT unit_code, CURRENT_USER, 'A', GETDATE() FROM DELETED  -- datos borrados de los registros (Antes del update)

	INSERT INTO estado_auditoria
	SELECT unit_code, CURRENT_USER, 'D', GETDATE() FROM INSERTED -- datos nuevos de los registros (Despues del update)
END
GO

SELECT * FROM productos_premium;

UPDATE productos_premium SET unit_code=0 WHERE unit_code = 6

TRUNCATE TABLE estado_auditoria; -- limpiamos la tabla, borrando todos los registros

SELECT * FROM estado_auditoria;

-----------------------------------------------------------------------------------------------
-- OTRO TRIGGER, INSTEAD OF...

CREATE TRIGGER productos_fabricante ON productos_premium
INSTEAD OF DELETE AS
BEGIN
	PRINT 'NO TE VOY A DEJAR BORRAR.. (?)'
END

SELECT * FROM productos_premium;
DELETE productos_premium WHERE unit_code='2'
SELECT * FROM productos_premium WHERE unit_code='2'

--INSERT INTO productos_premium (stock_num, unit_code, manu_code) VALUES (1, 500, 'MAN')


-----------------------------------------------------------------------------------------------
-- creamos esta tabla, para luego agregarle la columna "total", que la original NO  la tiene
-- y le asignamos un valor 0 como default
SELECT * INTO ordenesPremium FROM dbo.orders;
ALTER TABLE ordenesPremium 
ADD total INT NOT NULL DEFAULT (0);
GO

-- esto de aca no anda OK, pero bueno...
--ALTER TABLE ordenesPremium DROP CONSTRAINT total -- Si quisieramos borrar  la columna
--GO
--ALTER TABLE ordenesPremium DROP COLUMN total -- Si quisieramos borrar la columna
--GO

SELECT item_num, quantity, o.order_num, o.total FROM dbo.items i  JOIN ordenesPremium o ON i.order_num=o.order_num;

SELECT order_num, total from ordenesPremium WHERE order_num=1001;	-- vemos los valores antes del update
UPDATE items SET quantity=5 WHERE order_num=1001;					-- hacemos el update, el trigger deberia actualizar los registros
SELECT order_num, total from ordenesPremium WHERE order_num=1001;	-- vemos el valores despues del update

ALTER TRIGGER upd_items_ordenes ON items
AFTER UPDATE
AS
BEGIN
	DECLARE @i_precio_del dec(8,2), @n_orden int, @i_precio_ins dec(8,2) , @quantity_del int, @quantity_ins int;

	SELECT @i_precio_del=unit_price, @quantity_del=quantity FROM deleted
	SELECT @n_orden= order_num, @i_precio_ins=unit_price, @quantity_ins=quantity FROM inserted

	IF UPDATE (unit_price) OR UPDATE(quantity)
	BEGIN
		-- Como no podia imprimir el dec(8,2) lo pasé a string, 
		SELECT FORMATMESSAGE('@quantity_del=%i, @i_precio_del=%s', @quantity_del, CAST(@i_precio_del AS VARCHAR));  -- podes castearlo el dec(8,2)
		SELECT FORMATMESSAGE('@quantity_ins=%i, @i_precio_ins=%s', @quantity_ins, CONVERT(varchar, @i_precio_ins)); -- o podes convertirlo el dec(8,2)
		
		-- modifica la columna total, en todos los registros
		UPDATE ordenesPremium SET total = total
		-(@quantity_del*@i_precio_del)	-- como sabe cual tomar? entre este y el de abajo?
		+(@quantity_ins*@i_precio_ins)
		WHERE order_num = @n_orden;
	END
END
