USE databases_for_analysts;

-- для второго дз

DROP TABLE IF EXISTS table_for_dz2;
CREATE TABLE table_for_dz2 SELECT * FROM `orders_201908221-test`;

-- пошли по колонкам данные изучать по всякому:
-- PRICE
-- есть отрицательные цены, как так? Удалим их и все, что ценой меньше 100-ти
DELETE FROM table_for_dz2 WHERE price < 100;
-- снесём все заказы выше 150000 р.
DELETE FROM table_for_dz2 WHERE price > 150000;
-- выпадений нет
SELECT * FROM table_for_dz2 WHERE id_o = '' OR id_o IS NULL OR user_id = '' OR user_id IS NULL OR price = '' OR price IS NULL OR o_date  IS NULL; 

-- USER_ID
-- удалим тех, у кого заказов больше 2000 шт.
DROP TEMPORARY TABLE IF EXISTS id_to_delete;
CREATE TEMPORARY TABLE id_to_delete SELECT user_id FROM table_for_dz2 GROUP BY user_id HAVING COUNT(user_id) > 2000;
DELETE FROM table_for_dz2 WHERE user_id IN (SELECT user_id FROM id_to_delete);

-- ID_O
-- смотрим, нет ли одинаковых id у заказов, ура, нет:
SELECT COUNT(*), COUNT(DISTINCT id_o) FROM table_for_dz2;

-- собираем и забираем в Excel общую сумму по месяцам
SELECT 
	YEAR(o_date) AS `year`, 
	MONTH(o_date) AS `month`, 
	ROUND(AVG(price)) AS `avg`, 
	ROUND(SUM(price)) AS `sum` 
FROM table_for_dz2 
GROUP BY `year`, `month`;

-- дальше работа с дз в Excel, в т.ч. два графика


-- Вопрос: почему прогноз получается выше факта?
-- Ответ: много факторов может повлиять, ну к примеру:
-- 1) исследуемые значенимя могут распределяться нелинейно
-- 2) в линейном прогнозе мы не учитываем маркетинговую активность и другие заложенные бюджеты, новые каналы рекламы и продвижения и т.п. => нужны поправочные коэффициенты
-- 3) конкетно в нашей задаче: если посмотреть на прирост по месяцам в 2017-м году по отношению к показателям 2016-гно года (график есть в Excel), то видно, 
--    что скорость прироста равномерна и ожидать больших скачков в 2018-м не стоило

