-- EJERCICIO 2
SELECT	c1.fname, c1.lname,
		SUM(i.quantity*i.unit_price)/COUNT(DISTINCT o.order_num) promedio_compra,
		t2.fname, t2.lname , t2.promedio_compra
FROM customer c1
JOIN orders o ON o.customer_num = c1.customer_num
JOIN items i ON i.order_num = o.order_num
JOIN ( 
	SELECT	c2.customer_num, fname, lname,
			SUM(i2.quantity*i2.unit_price)/COUNT(DISTINCT o2.order_num) promedio_compra
	FROM customer c2
	JOIN orders o2 ON o2.customer_num = c2.customer_num
	JOIN items i2 ON i2.order_num = o2.order_num
	GROUP BY c2.customer_num, fname, lname
) t2 ON t2.customer_num = c1.customer_num_referedBy
GROUP BY c1.fname, c1.lname, t2.fname, t2.lname , t2.promedio_compra
HAVING 
	t2.promedio_compra > SUM(i.quantity*i.unit_price)/COUNT(DISTINCT o.order_num)
ORDER BY c1.fname, c1.lname


-----------------------------------------------------------------
-- EJERCICIO 3

GO
CREATE PROCEDURE auditoria_fabricante @fecha_hasta DATETIME AS
BEGIN
	DECLARE @fecha_actual DATETIME
	DECLARE @nro_audit BIGINT, @fecha DATETIME, @accion CHAR(1),
			@manu_code char(3), @manu_name varchar(30), @lead_time smallint,
			@state char(2), @usuario VARCHAR(30)

	DECLARE ITEM_CURSOR CURSOR
	FOR SELECT nro_audit FROM audit_fabricante
	OPEN ITEM_CURSOR
	FETCH NOMBRE_CURSOR INTO @nro_audit, @fecha, @accion, @manu_code, @manu_name, @lead_time, @state, @usuario
	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRANSACTION
		BEGIN TRY
			IF(@accion = 'I')
				DELETE FROM manufact  WHERE manu_code = @manu_code AND (@fecha BETWEEN GETDATE() AND @fecha_actual)
			ELSE IF(@accion ='O')
				UPDATE manufact SET manu_name = @manu_name, lead_time = @lead_time, state = @state, f_alta_audit = @fecha, d_usualta_audit = @usuario
					WHERE manu_code = @manu_code AND (@fecha BETWEEN GETDATE() AND @fecha_actual)
			ELSE IF(@accion ='D')
				INSERT INTO manufact	(manu_code, manu_name, lead_time, state, f_alta_audit, d_usualta_audit)
							VALUES		(@manu_code, @manu_name, @lead_time, @state, @fecha, @usuario)
			COMMIT
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION

			DECLARE @descripcion VARCHAR(30)
			SET @descripcion = ERROR_MESSAGE()
			RAISERROR(@descripcion, 16, 1);
		END CATCH
	FETCH NOMBRE_CURSOR INTO @nro_audit, @fecha, @accion, @manu_code, @manu_name, @lead_time, @state, @usuario
	END
	CLOSE ITEM_CURSOR
	DEALLOCATE ITEM_CURSOR
END
GO



-- Ejercicio 4
CREATE TRIGGER orders_audit_baja ON orders
INSTEAD OF DELETE AS
BEGIN
	DECLARE @order_num SMALLINT, @customer_num SMALLINT

	DECLARE ITEM_CURSOR CURSOR
	FOR SELECT order_num FROM deleted
	OPEN ITEM_CURSOR
	FETCH ITEM_CURSOR INTO @order_num, @customer_num
	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRANSACTION
		BEGIN TRY
			IF((SELECT COUNT(*) FROM orders WHERE customer_num=@customer_num) < 5)
				UPDATE orders
				SET flag_baja=1, fecha_baja=GETDATE(), user_baja=CURRENT_USER
					WHERE order_num = @order_num
			ELSE
				INSERT INTO BorradosFallidos	(customer_num, order_num, fecha_baja, user_baja)
									VALUES		(@customer_num, @order_num, GETDATE(), CURRENT_USER)

			COMMIT
		END TRY
		BEGIN CATCH
			ROLLBACK
			DECLARE @descripcion VARCHAR(30)
			SET @descripcion = ERROR_MESSAGE()
			RAISERROR(@descripcion, 16, 1);
		END CATCH
	FETCH ITEM_CURSOR INTO @order_num, @customer_num
	END
	CLOSE ITEM_CURSOR
	DEALLOCATE ITEM_CURSOR
END

