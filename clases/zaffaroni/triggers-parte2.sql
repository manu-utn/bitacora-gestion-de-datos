USE stores7new;
-- NO ESTÁ TERMINADO...
SELECT * FROM x_items;

GO
CREATE TRIGGER audit_insert_items_error ON dbo.items
INSTEAD OF INSERT AS
BEGIN
	DECLARE @cantidad_items INT
	DECLARE @order_num INT

	SELECT @order_num=i.order_num, @cantidad_items=count(*)
	FROM inserted i
	JOIN orders o ON i.order_num=o.order_num
	JOIN customer c ON c.customer_num=o.customer_num
	GROUP BY i.order_num
	HAVING c.state='CA';

	IF(@cantidad_items)..

--	INSERT INTO x_items (item_num, order_num, stock_num, manu_code, quantity, unit_price)
--	SELECT item_num, order_num, stock_num, manu_code, quantity, unit_price FROM inserted i
END
GO
