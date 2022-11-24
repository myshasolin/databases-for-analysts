/*
Кому инетересно и есть время сделать итоговый проект по прогнозированию:
Надо спрогнозировать ТО по месяцам за 2019. В исходнике - все данные по продажам с 2013 года - orders_all ( orders_all https://drive.google.com/drive/u/0/folders/1C3HqIJcABblKM2tz8vPGiXTFT7MisrML ). 
Нужно учесть пробои данных, некорректность. Т.е. в некоторых месяцах проставить поправочные коэффициенты. 
Ваша задача - глубоко проанализировать, как развивался магазин, как менялись ср чеки, повторность продаж, тренд и сделать скорректирвоанный план на 2019 год по месяцам.
В качестве вывода: строите график ТО по месяцам за 2019 год и детально описываете, что учитывали для прогноза в pdf.
*/

USE databases_for_analysts;

-- ну поехали
-- кладём файл сюда
SHOW VARIABLES LIKE 'secure_file_priv';

-- создаём каркас и заливаем в него данне
DROP TABLE IF EXISTS orders_all; 
CREATE TABLE orders_all(
	id_o INT,
	user_id INT,
	price DOUBLE,
	o_date VARCHAR(12));

-- зальём в таблицу данные из csv-файла
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders_all.csv'
INTO TABLE orders_all
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- ля что имеем
DESCRIBE orders_all;

-- данные у нас за 2013-2018-е гг, других годов в o_date через LIKE не находим, ок
SELECT * FROM orders_all WHERE o_date LIKE '%2013%'; -- AND o_date LIKE '%2014% и т.п.

-- ищем пропуски, как найдём, грохнем их (спойлер - ничего криминального не нашлось)
SELECT * FROM orders_all WHERE id_o IS NULL OR id_o = '' OR user_id IS NULL OR user_id = '' AND user_id <> 0 AND price IS NULL AND price = '' AND o_date IS NULL OR o_date = '';

-- пошли по столбцам
-- id_o - смотрим, нет ли одинаковых (спойлер - нет)
SELECT COUNT(*), COUNT(DISTINCT id_o), (CASE WHEN COUNT(*) = COUNT(DISTINCT id_o) THEN 'да' ELSE 'нет' END) AS 'совпадает ли кол-во?' FROM orders_all;

-- o_date
-- вот у нас есть пустышки, их 55492 штуки. У них у всех большие => свежие user_id, нулеые заказы и даты заказов '00.00.0000'. Грохнем их без сожаления
SELECT * FROM orders_all WHERE o_date LIKE '00.00.0000';
DELETE FROM orders_all WHERE o_date LIKE '00.00.0000';

-- а вообще пришлось при загрузке дату сохранить как VARCHAR, так как она нормально заливаться не хотела
-- через dbForge или dBeaver вылетала ошибка на 2136570 строке и загрузка ломалась
-- а через MongoDB или LOAD DATA при указании типа данных DATE даты перекашивало аж до 2030-го какого-то года
-- сделаем теперь дату нормальной датой типа DATE через функцию STR_TO_DATE()
START TRANSACTION;
DROP TABLE IF EXISTS temp;
CREATE TABLE temp SELECT id_o, user_id, price, STR_TO_DATE(o_date, '%d.%m.%Y') o_date FROM orders_all;
DROP TABLE orders_all;
RENAME TABLE temp TO orders_all;
COMMIT;
-- вроде как всё с датами стало более-менее прилично, в группировке месяц-год ничего левого не проскочило
SELECT *, DATE_FORMAT(o_date, '%Y%m') cohort FROM orders_all GROUP BY cohort;
-- как и в группировке по дням
SELECT *, DATE_FORMAT(o_date, '%d') cohort FROM orders_all GROUP BY cohort ORDER BY cohort;

-- user_id
-- есть покупатели с большим кол-вом повторений. Но.
-- 1) у них не новые user_id и достаточно широкая история заказов. Например, id=2987887 появился в начале 2017-го и вплоть до декабря 2019-го делает заказы
-- 2) эти id точно какие-то колл-центры или маркетплейсы. Удалять их не стоит, т.к., хоть это не розничные покупатели, но они сильно размазаны по годам и влияют на статистику
SELECT COUNT(user_id) AS `count`, user_id FROM orders_all GROUP BY user_id ORDER BY `count` DESC;
SELECT * FROM orders_all WHERE user_id = 2987887 ORDER BY o_date DESC;

-- price
-- смотрим минимальный price. Нулей 45 строк, отрицательных 9 шт.
SELECT * FROM orders_all WHERE price < 0;
SELECT * FROM orders_all WHERE price = 0;
-- Из минусовых только у user_id=471946 похоже на то, что минус - это опечатка, остальные суммы у всех слишком мелкие.
-- вручную изменим эту сумму с минуса на плюс, а остальные минусовые заказы удалим со всеми заказами вообще ниже 50-ти единиц денег 
UPDATE orders_all SET price = 2086 WHERE id_o = 1155915;
DELETE FROM orders_all WHERE price < 50;

-- смотрим максимальный price
SELECT price FROM orders_all ORDER BY price DESC;
-- там жесть, особнно первый. Похоже, кто-то уснул на клавиатуре, вот такая цена и получилась)) 
-- у покупателя с user_id = 7265 больше нет заказов, так что это точно выброс
-- ну и вот покупатель user_id = 9573142 сделал 2 заказа в конце декабря 2018-го почти на два ляма, подозрительненько. Снесём большой заказ
-- остальные заказы похожи на b2b, порадуемся крупным сделкам и оставим их в покое
DELETE FROM orders_all WHERE price > 1000000;

-- О декабре.
-- такое дело. У нас в декабре 2018-го ешё 4-х дней не хватает
SELECT * FROM orders_all GROUP BY o_date ORDER BY o_date DESC;

-- на 28-31 декабря посчитаем поправочный коэффициент. Возьмём среднее на эти дни в разные годы и % роста год к году. Его к декабрю 2018-го и прибавим.
-- 2014-2015-е гг. не рассматриваем, так как эти годы стартовые и с нездоровым ростом в 252 и 188 процентов
-- в 2016-м же году рост 45%, а в 2017 20%. Дельта между ними в 44,4%, а значит рост в 2018-м можно ожидать где-то на уровне 11,12% от 2017-го
-- напишем лютый велосипед, который по всем коэффициентам посчитает и получит сумму 2017г.+11.12%
SELECT 
	*,
	ROUND(
		`2017`.age_2017 * (
			((ROUND(((`2017`.age_2017 / `2016`.age_2016)-1)*100) * 
			(1-ROUND(ROUND(((`2017`.age_2017 / `2016`.age_2016)-1)*100) / 
			ROUND(((`2016`.age_2016 / `2015`.age_2015)-1)*100), 2)))/100)+1
		)
	) `age_2018 predict`
FROM
	(SELECT SUM(price) age_2013 FROM orders_all WHERE o_date BETWEEN '2013-12-28' AND '2013-12-31') `2013`,
	(SELECT SUM(price) age_2014 FROM orders_all WHERE o_date BETWEEN '2014-12-28' AND '2014-12-31') `2014`,
	(SELECT SUM(price) age_2015 FROM orders_all WHERE o_date BETWEEN '2015-12-28' AND '2015-12-31') `2015`,
	(SELECT SUM(price) age_2016 FROM orders_all WHERE o_date BETWEEN '2016-12-28' AND '2016-12-31') `2016`,
	(SELECT SUM(price) age_2017 FROM orders_all WHERE o_date BETWEEN '2017-12-28' AND '2017-12-31') `2017`,
	(SELECT SUM(price) age_2018 FROM orders_all WHERE o_date BETWEEN '2018-12-28' AND '2018-12-31') `2018`;

-- сохраним посчитанный выше результат в переменную
SET@`28-31.12.2018` := 
(SELECT 
	ROUND(
		`2017`.age_2017 * (
			((ROUND(((`2017`.age_2017 / `2016`.age_2016)-1)*100) * 
			(1-ROUND(ROUND(((`2017`.age_2017 / `2016`.age_2016)-1)*100) / 
			ROUND(((`2016`.age_2016 / `2015`.age_2015)-1)*100), 2)))/100)+1
		)
	) `age_2018 predict`
FROM
	(SELECT SUM(price) age_2015 FROM orders_all WHERE o_date BETWEEN '2015-12-28' AND '2015-12-31') `2015`,
	(SELECT SUM(price) age_2016 FROM orders_all WHERE o_date BETWEEN '2016-12-28' AND '2016-12-31') `2016`,
	(SELECT SUM(price) age_2017 FROM orders_all WHERE o_date BETWEEN '2017-12-28' AND '2017-12-31') `2017`,
	(SELECT SUM(price) age_2018 FROM orders_all WHERE o_date BETWEEN '2018-12-28' AND '2018-12-31') `2018`);

-- вот она
SELECT @`28-31.12.2018`;

-- добавим вычисленный поправочный коэффициент в декабрь 2018-го как отдельный заказ со своим user_id и номером
INSERT INTO orders_all VALUES(10985369, 9900290, @`28-31.12.2018`, '2018-12-31');

-- теперь декабрь выглядит так
SELECT * FROM orders_all ORDER BY o_date DESC;

-- далее для Excel соберём суммы продаж по месяцам. Это поможет нам:
-- во-первых, построить график и визуально оценить рост продаж,
-- во вторых, построить линейный прогноз на 2019-й год
SELECT 
	YEAR(o_date) AS `year`, 
	MONTH(o_date) AS `month`, 
	ROUND(AVG(price)) AS `avg`, 
	ROUND(SUM(price)) AS `sum`,
	ROUND(AVG(SUM(price)) OVER(PARTITION BY YEAR(o_date)), 2) AS `average annual`
FROM orders_all
GROUP BY `year`, `month`;

-- по сгруппированным данным мы видим, что продажи стартовали с 2013-го года и среднегодовой рост выручки по сравнении с прошедшим годом выглядел так:
-- 2014-й год 436.23%
-- 2015-й год 112.83%
-- 2016-й год 59.73%
-- 2017-й год 51.68%
-- 2018-й год 25.31%
-- в Excel на эту тему есть симпатичный графичек с линейным трендом
-- резкий рост в самом начале может нам помешать, так что будем прогнозировать 2019-й год на основе данных за 2016-2018-й гг.

-- ПРОГНОЗ
-- Прогноз цен на 2019-й год мы можем сделать по такому же принципу, по которому спрогнозировали последние 4 дня декабря, т.е.
-- 1) найти % прироста по месяцам в 2017-м году по отношению к 2016-му и в 2018-м году по отношению к 2017-му
-- 2) найти соотношение между этими %-ми прироста и 
-- 3) это соотношение как коэффициент роста в 2019-м году по отношению к 2018-му, прибавить к значениям 2018-го года
-- сама формула схематически такая:
-- (2018) + ((-1*( (% 2018 от 2017) * ((% от 2018 от 2017) / (% 2017 от 2016)) )) / 100 * 2018)
-- считать будем в процедуре, которая за 12 итераций заполнит таблицу forecast_for_2019 данными прогноза на 12 месяцев
-- а пока создадим костяк этой таблицы со столбцом дат, он будет служит дополнительной страховкой того, что все данные записались верно в свои месяцы,
-- т.к. мы же знаем, что MySQL не сортирует строки и нет чёткой гарантии того, что они не перемешаются, а нас не проведёшь))

DROP TABLE IF EXISTS forecast_for_2019;
CREATE TABLE forecast_for_2019(o_date DATE, predict INT DEFAULT NULL);
INSERT INTO forecast_for_2019 (o_date) VALUES ('2019-01-01'), ('2019-02-01'), ('2019-03-01'), ('2019-04-01'), 
('2019-05-01'), ('2019-06-01'), ('2019-07-01'), ('2019-08-01'), ('2019-09-01'), ('2019-10-01'), ('2019-11-01'), ('2019-12-01');

DELIMITER //
DROP PROCEDURE IF EXISTS revenue_forecast_preparation//
CREATE PROCEDURE revenue_forecast_preparation(base_range CHAR(10))
BEGIN
	DECLARE january2018, january2017, january2016 BIGINT;
	SET january2018 = (SELECT ROUND(SUM(price)) FROM orders_all WHERE o_date BETWEEN base_range AND LAST_DAY(base_range));
	SET january2017 = (SELECT ROUND(SUM(price)) FROM orders_all WHERE o_date BETWEEN (base_range - INTERVAL 1 YEAR) AND LAST_DAY((base_range - INTERVAL 1 YEAR)));
	SET january2016 = (SELECT ROUND(SUM(price)) FROM orders_all WHERE o_date BETWEEN (base_range - INTERVAL 2 YEAR) AND LAST_DAY((base_range - INTERVAL 2 YEAR)));

	UPDATE forecast_for_2019
	SET predict = 
	(SELECT
		ROUND(january2018 + `% increase`) AS `january` 
	FROM
		(SELECT
			(-1 *
				ROUND((january2018/january2017-1), 4) * 
				ROUND((ROUND(((january2018 / january2017-1)*100), 2) / ROUND(((january2017 / january2016-1)*100), 2)-1)*100, 2)
			) / 100 * january2018 AS `% increase`
		) `table`)
	WHERE forecast_for_2019.o_date = base_range + INTERVAL 1 YEAR;
END//
DELIMITER ;


DELIMITER //
DROP PROCEDURE IF EXISTS repeat_call//
CREATE PROCEDURE repeat_call()
BEGIN
	DECLARE i INT DEFAULT 12;
	DECLARE start_time CHAR(10);
	SET start_time = '2017-12-01';
	REPEAT
		SET start_time = start_time + INTERVAL 1 MONTH;
		CALL revenue_forecast_preparation(start_time);
		SET i = i-1;
	UNTIL i <= 0
	END REPEAT;
END//
DELIMITER ;

CALL repeat_call;

-- во чё вышло - по месяцам c процентом роста в сравнении с 2018-м годом
-- график с показателями за всё время + спрогнозированным 2019-м годом есть в Excel
SELECT 
	fc.o_date,
	oa.`sum` AS `2018`,
	fc.predict AS `2019`,
	ROUND(((fc.predict / oa.`sum`)-1)*100, 2) AS `%`
FROM forecast_for_2019 fc
JOIN 
(SELECT 
	ROUND(SUM(price)) AS `sum`,
	o_date
FROM orders_all
GROUP BY YEAR(o_date), MONTH(o_date)) AS oa
ON fc.o_date = oa.o_date+INTERVAL 1 YEAR;

-- ДОПОЛНИТЕЛЬНО
-- для более точного прогноза можно учесть вагон и тележку самых разных тонкостей, вроде роста денег от новых, изменения среднего чека, периодичности закупок и пр.,
-- но не факт, что наворотив всех этих плюх мы не сделаем хуже, так как динейно и без наворотов видно, что магазин уже к 18-му году вышел на плато и у нас нет данных, которые
-- позволили бы сказать, что в 2019-м году выручка резко подпрыгнет вверх, скорее наоборот, мы видим от года к году постепенное снижение роста.
-- в реальной жизни было бы неплохо знать всякие там маркетинговые бюджеты, запланированные на год кампании, планы по работе с ассортиментом (его ширина, глубина и пр.).
-- Всё это позволило бы добавить поправочных коэффициентов в подходящие периоды и уже прогнозировать выручку на 2019-й год с ними.
-- Тем более, что прогноз составлялся годовой на 12 месяцев, а не посуточный.

-- Плюс в прогнозе 2019-го года я не стал учитывать как-то отдельно новых, так как доля изменения % новых по кварталам на протяжении всей жизни магазина практически неизменна,
-- доля денег от новых по кварталам держится в диапазоне 56-58%,
-- а доля количества новых по кварталам вообще линейно растёт от 46 до 56% за 12 кварталов
-- об этом есть два скромных графика в Excel, а собирал квартальную статистику я так (это такой получается мини-бонус к аналитике продаж):

-- создадим таблицу sales_and_customer_data, она поможет нам в процедуре собрать сводную таблицу по 12-ти кварталам
DROP TABLE IF EXISTS sales_and_customer_data;
CREATE TABLE sales_and_customer_data (
	`year_month` CHAR(6),
	all_users BIT,
	sum_count INT DEFAULT NULL, 
	sum_price INT DEFAULT NULL
);

-- ну а вот и сама процедура
DELIMITER //
DROP PROCEDURE IF EXISTS collect_statistics//
CREATE PROCEDURE collect_statistics (base_range CHAR(10))
BEGIN

INSERT INTO sales_and_customer_data
SELECT 
	DATE_FORMAT(base_range, '%Y%m'),
	1,
	COUNT(*),
	SUM(price)
FROM orders_all 
WHERE o_date BETWEEN base_range AND LAST_DAY(base_range);

INSERT INTO sales_and_customer_data
SELECT 
	DATE_FORMAT(base_range, '%Y%m'),
	0,
	COUNT(*),
	SUM(price)
FROM orders_all 
WHERE o_date BETWEEN base_range AND LAST_DAY(base_range)
AND user_id NOT IN (SELECT DISTINCT user_id FROM orders_all WHERE o_date < base_range);

END//
DELIMITER ;

-- вызываем процедуру итерационно 36 раз
DELIMITER //
DROP PROCEDURE IF EXISTS repeat_call//
CREATE PROCEDURE repeat_call()
BEGIN
	DECLARE i INT DEFAULT 36;
	DECLARE start_time CHAR(10);
	SET start_time = '2015-12-01';
	REPEAT
		SET start_time = start_time + INTERVAL 1 MONTH;
		CALL collect_statistics(start_time);
		SET i = i-1;
	UNTIL i <= 0
	END REPEAT;
END//
DELIMITER ;

CALL repeat_call;

-- соберём из получившейся sales_and_customer_data такую вот одну сводную таблицу table_for_dz9, а ней поля:
-- year_month - месяц года
-- quarter - квартал
-- all_count - все уникальные покупатели в этом месяце
-- all_price - товарооборот всех
-- new_count - все новые покупатели в этом месяце
-- new_price - товарооборот новых
-- old_count - все старые покупатели в этом месяце
-- old_price - товарооборот старых
-- % - % изменения по отношению к предыдущему месяцу
-- share of new - доля новых
-- share of new money - доля денег от новых
DROP TABLE IF EXISTS table_for_dz9;
CREATE TABLE table_for_dz9;
SELECT 
	`all`.`year_month`, 
	NTILE(12) OVER() `quarter`,
	`all`.sum_count all_count, 
	ROUND(((`all`.sum_count / LAG(`all`.sum_count) OVER())-1)*100, 2) AS '% all_count',
	`all`.sum_price all_price, 
	ROUND(((`all`.sum_price / LAG(`all`.sum_price) OVER())-1)*100, 2) AS '% all_price',
	`new`.sum_count new_count, 
	ROUND(((`new`.sum_count / LAG(`new`.sum_count) OVER())-1)*100, 2) AS '% new_count',
	`new`.sum_price new_price,
	ROUND(((`new`.sum_price / LAG(`new`.sum_price) OVER())-1)*100, 2) AS '% new_price',
	`all`.sum_count - `new`.sum_count old_count,
	ROUND((((`all`.sum_count - `new`.sum_count) / LAG(`all`.sum_count - `new`.sum_count) OVER())-1)*100, 2) AS '% old_count',
	`all`.sum_price - `new`.sum_price old_price,
	ROUND((((`all`.sum_price - `new`.sum_price) / LAG(`all`.sum_price - `new`.sum_price) OVER())-1)*100, 2) AS '% old_price',
	ROUND(`new`.sum_count / `all`.sum_count * 100, 2) `share of new in %`,
	ROUND(`new`.sum_price / `all`.sum_price * 100, 2) `share of new money in %`
FROM
	(SELECT `year_month`, sum_count, sum_price
	FROM sales_and_customer_data 
	WHERE all_users = 1) `all`
	JOIN 
	(SELECT `year_month`, sum_count, sum_price
	FROM sales_and_customer_data 
	WHERE all_users = 0) `new`
	ON `all`.`year_month` = `new`.`year_month`
ORDER BY `all`.`year_month`;


-- за 12 кварталов % денег от новых - практически неизменная переменная, линейно она выросла с 55,8% до 57,4%, т.е. на 1,6% 
SELECT 
	`quarter`,
	AVG(`share of new money in %`) OVER(PARTITION BY quarter) AS `quarterly average in money`
FROM table_for_dz9
GROUP BY `quarter`;

-- по доле количества новых в квартале в % тренд роста стабильней, но их денежный коэффициент выше
SELECT 
	`quarter`,	
	AVG(`share of new in %`) OVER(PARTITION BY quarter) AS `quarterly average in money`
FROM table_for_dz9
GROUP BY `quarter`;


