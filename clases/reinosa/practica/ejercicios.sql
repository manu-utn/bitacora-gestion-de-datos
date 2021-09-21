
-- dbo: data base owner

-- caso interesante, podemos usar una "función de usuario" en las columnas del select
-- usando valores de las columnas
SELECT dbo.funcion(stock_producto, stock_producto) FROM stock;

--> Aclaración del Ej. (9)
--> 1.el movimiento se refiere reducir la cant. el stock de los articulos que conforman el combo
--> en la tabla Stock
--> 2. sólo un trigger que espera un "after update" puede leer de las tablas "inserted" y "deleted"
