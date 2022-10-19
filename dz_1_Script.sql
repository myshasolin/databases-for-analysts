-- DROP DATABASE IF EXISTS databases_for_analysts;
-- CREATE DATABASE databases_for_analysts;
-- USE databases_for_analysts;

-- посмотрим, откуда начинать импорт файла, туда его и положим
SHOW VARIABLES LIKE 'secure_file_priv';

-- создаём пустую таблицу
DROP TABLE IF EXISTS orders_20190822; 
CREATE TABLE orders_20190822(
	id_o INT,
	user_id INT,
	price VARCHAR(50),
	o_date VARCHAR(50));

-- вот она:
DESCRIBE orders_20190822;

-- зальём в таблицу данные из csv-файла
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders_20190822.csv'
INTO TABLE orders_20190822
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- проверим заполнение и количество строк
SELECT * FROM orders_20190822;
SELECT COUNT(*) FROM orders_20190822;

-- проверим количество пропусков и сразу, если что, грохнем их (52 строчки)
SELECT * FROM orders_20190822 WHERE id_o = '' OR id_o = NULL OR user_id = '' OR user_id = NULL OR price LIKE '0,%' OR o_date = '' OR o_date = NULL;
DELETE FROM orders_20190822 WHERE id_o = '' OR id_o = NULL OR user_id = NULL OR price LIKE '0,%' OR o_date = '' OR o_date = NULL;


-- в получившейся таблице цена с запятой и типа VARCHAR и дата в виде строки - исправим эти столбцы на FLOAT и DATA, соответственно
-- как? создадим такой же каркас для второй таблицы, только price в ней будет типа FLOAT, а o_date типа DATE
-- и в процедуре пройдёмся курсором по старой таблице, заполняя её данными новую таблицу, но уже с отформатированными значениеми price и o_data
DROP TABLE IF EXISTS orders_table_price_float; 
CREATE TABLE orders_table_price_float(
	id_o INT,
	user_id INT,
	price FLOAT,
	o_date DATE);

DESCRIBE orders_table_price_float;

DELIMITER $$
DROP PROCEDURE IF EXISTS copy_db_orders$$
CREATE PROCEDURE copy_db_orders()
BEGIN
	DECLARE id_o, user_id INT; 
	DECLARE price, o_date VARCHAR(50);
	DECLARE is_end INT DEFAULT 0;

	DECLARE curcat CURSOR FOR SELECT * FROM orders_20190822;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET is_end = 1;

	OPEN curcat;
		cyc: LOOP
			FETCH curcat INTO id_o, user_id, price, o_date;
			IF is_end = 1 THEN
				LEAVE cyc;
			END IF;
			INSERT IGNORE INTO orders_table_price_float VALUES(
				id_o,
				user_id,
				ROUND(CONVERT((REPLACE(price, ',', '.')), FLOAT), 2), 
				STR_TO_DATE(o_date, '%d.%m.%Y'));
		END LOOP cyc;
	CLOSE curcat;
END$$
DELIMITER ;

CALL copy_db_orders();

-- проверим
SELECT * FROM orders_table_price_float ORDER BY price DESC;
SELECT (SELECT COUNT(*) FROM orders_20190822) AS orders_20190822, (SELECT COUNT(*) FROM orders_table_price_float) AS orders_table_price_float;

-- на всякий случай, чтоб не повредить полученную новую таблицу, которая формировалась час с лишним, работать будем с её копией. Создадим копию
DROP TABLE IF EXISTS copy_orders_table_price_float;
CREATE TABLE copy_orders_table_price_float SELECT * FROM orders_table_price_float;

-- пошли по колонкам данные изучать по всякому:
-- PRICE
-- смотрим минимальный price
SELECT price FROM copy_orders_table_price_float ORDER BY price;
-- есть отрицательные цены, как так? Удалим их и все, что ценой меньше 50-ти
DELETE FROM copy_orders_table_price_float cotpf WHERE price < 50

-- смотрим максимальный price
SELECT price FROM copy_orders_table_price_float cotpf ORDER BY price DESC;
-- ну один самый крупный снесём, уж больно он выбивается из всех остальных, похож на выброс. Остальные крупные похожи на b2b-заказы, что допустимо
DELETE FROM copy_orders_table_price_float cotpf ORDER BY price DESC LIMIT 1;

-- USER_ID
-- проверим, нет ли частых повторений у user_id - ну вот есть один user_id=765861 с повторами 3182 раза.
-- но на 2 с хвостом миллиона строк это 0,15%, так что будем считать, что норм, просто активный покупатель
DESCRIBE copy_orders_table_price_float;
SELECT COUNT(user_id) AS `count`, user_id FROM copy_orders_table_price_float cotpf GROUP BY user_id ORDER BY `count` DESC;

-- ID_O
-- смотрим, нет ли одинаковых id у заказов, ура, нет:
SELECT COUNT(*), COUNT(DISTINCT id_o) FROM copy_orders_table_price_float;

-- O_DATE
-- мы свойствах файла orders_20190822.csv можем посмотреть дату последнего изменения файла, вот так:

-- \! for %x in ('C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders_20190822.csv') do (echo %~nx %~tx)
-- C:\ProgramData\MySQL\MySQL Server 8.0\Uploads>(echo orders_20190822 22.08.2019 07:38 )
-- orders_20190822 22.08.2019 07:38

-- получается, что все даты выше 22.08.2019 г. будут некорректные. Посмотрим, есть ли у нас такие (спойлер - нет таких)
SELECT * FROM copy_orders_table_price_float WHERE o_date >= '2019-08-22';

-- а что с нижней планкой? Есть ли выбросы и левые года? Проверяем количество строк в году - всё норм
SELECT YEAR(o_date) AS `year`, COUNT(*) AS `count` FROM copy_orders_table_price_float GROUP BY `year`; 

-- посмотрим на количество заказов по дням, отсортировав их по возрастанию. Так мы можем прикинуть, нет ли "странностей" в данных
SELECT CONCAT(DAYOFMONTH(o_date), ', ',
	CASE
		WHEN MONTH(o_date) = 1 THEN 'январь'
		WHEN MONTH(o_date) = 2 THEN 'февраль'
		WHEN MONTH(o_date) = 3 THEN 'март'
		WHEN MONTH(o_date) = 4 THEN 'апрель'
		WHEN MONTH(o_date) = 5 THEN 'май'
		WHEN MONTH(o_date) = 6 THEN 'июнь'
		WHEN MONTH(o_date) = 7 THEN 'июль'
		WHEN MONTH(o_date) = 8 THEN 'август'
		WHEN MONTH(o_date) = 9 THEN 'сентябрь'
		WHEN MONTH(o_date) = 10 THEN 'октябрь'
		WHEN MONTH(o_date) = 11 THEN 'ноябрь'
		ELSE 'декабрь'
	END, ', ',
	YEAR(o_date), ' ', 'год'
) AS `date`, COUNT(*) FROM copy_orders_table_price_float GROUP BY o_date ORDER BY COUNT(*);
-- ожидаемо "провальные" по заказам дни - это дни перед длинными праздниками, а "хорошие" дни - вторая половина IV-го квартала, похоже на правду

-- данные почистили, более-менее проверили, приступаем к остальным этапам дз:

-- 2. Проанализировать, какой период данных выгружен
SELECT MONTH(o_date) AS `month`, YEAR(o_date) AS `year` FROM copy_orders_table_price_float GROUP BY `month`, `year`;
-- период данных - 2016-й и 2017-й года

-- 3. Посчитать кол-во строк, кол-во заказов и кол-во уникальных пользователей, кот совершали заказы.
-- изначально количество строк = 2002752 
SELECT COUNT(*) FROM orders_20190822;
-- после обработки данных строк осталось = 1999462
-- уникальных пользователей 1014352 
SELECT COUNT(*) FROM copy_orders_table_price_float;
SELECT 
	(SELECT COUNT(id_o) FROM copy_orders_table_price_float) AS `количество заказов`, 
	(SELECT COUNT(DISTINCT user_id) FROM copy_orders_table_price_float) AS `количество уникальных пользователей`;

-- 4. По годам и месяцам посчитать средний чек, среднее кол-во заказов на пользователя, сделать вывод , как изменялись это показатели Год от года.

-- общую сумму по месяцам посмотреть можно так:
SELECT 
	YEAR(o_date) AS `year`, 
	MONTH(o_date) AS `month`, 
	ROUND(SUM(price)) AS `sum` 
FROM copy_orders_table_price_float 
GROUP BY `year`, `month`;

-- а вот средняя годовая выручка. Для 2016 г. это 4929280, а для 2017 г. 7500387, выросли аж на 52% от показателей прошлого года
SELECT
ROUND((SELECT ROUND(SUM(price)) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2016)/(SELECT COUNT(DISTINCT o_date) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2016)) 
AS `дневная выручка в 2016`,
ROUND((SELECT ROUND(SUM(price)) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2017)/(SELECT COUNT(DISTINCT o_date) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2017)) 
AS `дневная выручка в 2017`;

-- в среднем суточный чек по годам, в 2016-м это 2101 денежных знаков, а в 2017-м 2400, суточный чек за год вырос на 14%
SELECT
ROUND((SELECT ROUND(SUM(price)) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2016)/(SELECT COUNT(DISTINCT id_o) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2016)) 
AS `средний чек 2016`,
ROUND((SELECT ROUND(SUM(price)) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2017)/(SELECT COUNT(DISTINCT id_o) FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2017)) 
AS `средний чек 2017`;

-- средний чек по месяцам, здесь видим тренд на полный вперёд и радуемся этому, хлопаем в ладоши
-- показатель роста среднего чека по месяцам добавил в Excel и построил по него симпатичный график
SELECT 
	YEAR(o_date) AS `year`, 
	MONTH(o_date) AS `month`, 
	ROUND(AVG(price)) AS `sum` 
FROM copy_orders_table_price_float 
GROUP BY `year`, `month`;

-- всего заказов у каждого пользователя:
SELECT user_id, COUNT(user_id) AS `count` FROM copy_orders_table_price_float GROUP BY user_id;

-- среднее количество заказов на пользователя 1,97 штук
SET @unique_users := (SELECT COUNT(*) FROM (SELECT COUNT(user_id) FROM copy_orders_table_price_float GROUP BY user_id) AS c);
SET @all_orders := (SELECT COUNT(id_o) FROM copy_orders_table_price_float);
SELECT @all_orders AS 'всего заказов', @unique_users AS 'уникальных покупателей', ROUND(@all_orders/@unique_users, 2) AS `среднее кол-во заказов на одного покупателя`;

-- 5. Найти кол-во пользователей, кот покупали в одном году и перестали покупать в следующем.
-- таких пользователей 359605 уникальных голов, что составляет в среднем 35% от общего количества уникальных пользователей
SET @users_2016 := (SELECT COUNT(DISTINCT user_id) FROM copy_orders_table_price_float WHERE user_id NOT IN (SELECT user_id FROM copy_orders_table_price_float WHERE YEAR(o_date) = 2017));
SELECT @users_2016 AS `покупатели 2016 г., которых нет в 2017-м`, (ROUND(@users_2016/@unique_users*100)) AS `это % от общего кол-ва уникальных покупателей`;

-- 6. Найти ID самого активного по кол-ву покупок пользователя.
-- это пользователь с id=765861, у него 3182 заказа
SELECT user_id AS `id покупателя-красавчика`, COUNT(user_id) AS `всего заказов у него` FROM copy_orders_table_price_float cotpf GROUP BY user_id ORDER BY `всего заказов у него` DESC LIMIT 1;

-- 7. Найти коэффициенты сезонности по месяцам, сделать предположение об аномалии (если она есть)
-- решение в таблице в Excel, там же график среднего чека по месяцам
-- а данные для Excel взяты так:
SELECT 
	YEAR(o_date) AS `year`, 
	MONTH(o_date) AS `month`, 
	ROUND(SUM(price)) AS `sum`
FROM copy_orders_table_price_float 
GROUP BY `year`, `month`;

-- 8. Построить график вероятности второй покупки по дням сразу после первой
-- для примера выборки взял 100 покупателей, совершивших от 2-х до 10-ти заказов включительно
-- для графика полученные данные по ним перенесём в Excel, там и построим
-- "падение вероятности 2+ покупки, данные по количеству пользователей" и 
-- "рост кол-ва дней от 2-й до последующих покупок"
SELECT 
	user_id, 
	COUNT(user_id) AS `count`, 
	GROUP_CONCAT(
		o_date 
		ORDER BY o_date 
		SEPARATOR ', ') 
	AS `orders dates` 
FROM copy_orders_table_price_float 
GROUP BY user_id 
HAVING `count` >= 2 AND `count` <= 10 
LIMIT 100;


-- для получения кол-ва дней между первым и вторым заказом проделаем вот что:
-- создадим временную таблицу, в которую положим только user_id и даты заказов
-- сделаем ограничение в выборке клиентов по заказам, добавили только тех, кто сделал более 1-го заказа, но менее 50-ти, таких получится 239524 шт, более чем достаточно для объективной выборки
-- далее в процедуре курсором загоним эти данные в новую таблицу days_between_first_and_second_order, положив в неё user_id и разницу в днях между первым и вторым заказом
-- грузится где-то полчаса. Если не хочется ждать, то можно взять выборку поменьше

DROP TEMPORARY TABLE IF EXISTS sample_of_buyers;
CREATE TEMPORARY TABLE sample_of_buyers
SELECT 
	user_id,  
	GROUP_CONCAT( 
		o_date 
		ORDER BY o_date 
		SEPARATOR ', ') 
	AS `orders dates` 
FROM copy_orders_table_price_float 
GROUP BY user_id 
HAVING COUNT(user_id) > 1 AND COUNT(user_id) < 50;

SELECT * FROM sample_of_buyers;
SELECT COUNT(*) FROM sample_of_buyers;
DESCRIBE sample_of_buyers;

DROP TABLE IF EXISTS days_between_first_and_second_order;
CREATE TABLE days_between_first_and_second_order (user_id INT, difference_of_days INT);

DELIMITER $$
DROP PROCEDURE IF EXISTS insert_to_days_between_first_and_second_order$$
CREATE PROCEDURE insert_to_days_between_first_and_second_order()
BEGIN
	DECLARE user_id INT; 
	DECLARE `orders dates` TEXT;
	DECLARE is_end INT DEFAULT 0;

	DECLARE curcat CURSOR FOR SELECT * FROM sample_of_buyers;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET is_end = 1;

	OPEN curcat;
		cyc: LOOP
			FETCH curcat INTO user_id, `orders dates`;
			IF is_end = 1 THEN
				LEAVE cyc;
			END IF;
			INSERT IGNORE INTO days_between_first_and_second_order VALUES(
				user_id,
				TIMESTAMPDIFF(
					DAY, 
					SUBSTRING_INDEX(`orders dates`, ',', 1), 
					SUBSTRING_INDEX(SUBSTRING_INDEX(`orders dates`, ',', 2), ',', -1)
				)
			);
		END LOOP cyc;
	CLOSE curcat;
END$$
DELIMITER ;

CALL insert_to_days_between_first_and_second_order;

-- готово
SELECT * FROM days_between_first_and_second_order;
SELECT COUNT(*) FROM days_between_first_and_second_order;

-- ну и вот статистика выборки: самое малое время между 1-м и 2-м заказом = 0, самое долгое = 727 дней и среднее время = 72.5 дня
SELECT 
	MIN(difference_of_days) AS `минимальное время`, 
	MAX(difference_of_days) AS `максимальное время`, 
	AVG(difference_of_days) AS `среднее время` 
FROM days_between_first_and_second_order;


