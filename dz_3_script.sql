USE databases_for_analysts;

-- для третьего дз

-- Данные по маю 2017 г.:
-- все заказы мая после очистки данных от выбросов - 90729 шт., общих денег 215 094 052
-- новых покупателей 47693 шт. - денег от них 123 154 112
-- старых покупателей 43036 шт. - денег от них 91 939 940
-- вот так можно посмотреть список "старых" покупателей в мае. Они для нас будут контрольной группой для проверки
SELECT 
	id_o,
	user_id,
	price,
	o_date
FROM table_for_dz2 
WHERE o_date BETWEEN '2017-05-01' AND '2017-05-31'
AND user_id IN (SELECT DISTINCT user_id FROM table_for_dz2 WHERE o_date < '2017-05-01')
ORDER BY o_date;

-- контрольная цифра мая для нас = 215 094 052,6 денег
SET @actual_values := (SELECT ROUND(SUM(price), 2) FROM table_for_dz2 WHERE o_date BETWEEN '2017-05-01' AND '2017-05-31');
SELECT @actual_values `факт`


-- РАССУЖДАЕМ
-- в апреле 2016-го было:
-- старых покупателей 25218 шт., они принесли денег 46 130 801 единиц
-- новых покупателей 40813 шт., они принесли денег 91 263 364 единиц
-- доля новых в кол-ве 62%
-- а в деньгах их доля составила 66%
SELECT 
	COUNT(*)
	#SUM(price)
FROM table_for_dz2
WHERE o_date BETWEEN '2016-04-01' AND '2016-04-30';
AND user_id NOT IN (SELECT DISTINCT user_id FROM table_for_dz2 WHERE o_date < '2016-04-01');

-- в мае 2016-го было:
-- старых покупателей 24001 шт., они принесли денег 41 584 521 единиц
-- новых покупателей 29229 шт., они принесли денег 65 372 303 единиц
-- доля новых в кол-ве 55%
-- а в деньгах их доля составила 61%
SELECT 
	#COUNT(*)
	SUM(price)
FROM table_for_dz2
WHERE o_date BETWEEN '2016-05-01' AND '2016-05-31'
AND user_id NOT IN (SELECT DISTINCT user_id FROM table_for_dz2 WHERE o_date < '2016-05-01');

-- в среднем доля новых покупателей за апрель и май 2016-го составила 58,5%, а доля их денег = 63,5%
-- при прогнозе мая 2017-го будем опираться только на текущих клиентов, применяя к итоговому результату коэффициентом полученную долю новых в 2016-м году

-- так как работать предстоит только с базой до 01.05.2017, то оставим для себя данные за год до мая 2017, отрезав "будущее"
DROP TABLE IF EXISTS table_for_dz3; 
CREATE TABLE table_for_dz3 SELECT * FROM table_for_dz2 WHERE o_date BETWEEN '2016-04-01' AND '2017-04-30';

-- посмотрим переменную group_concat_max_len и увеличим её размер, чтоб в дальнейшем строка в GROUP_CONCAT не обрезалась
SHOW VARIABLES LIKE 'group_concat_max_len';
SET @@session.group_concat_max_len = 20000;

-- создаём временную таблицу с теми, кто до мая сделал больше 2-х заказов
DROP TEMPORARY TABLE IF EXISTS temporary_users;
CREATE TEMPORARY TABLE temporary_users
SELECT 
	user_id, 
	AVG(price) price, 
	COUNT(id_o) id_o,
	GROUP_CONCAT(o_date ORDER BY o_date SEPARATOR ', ') o_date
FROM table_for_dz3
GROUP BY user_id
HAVING COUNT(*) < 3;
-- удалим из неё записи старше полугода у тех, кто сделал всего один заказ
DELETE FROM temporary_users WHERE id_o = 1 AND o_date < '2016-11-01';
-- плюс удалим тех, кто сделал 2 заказа, но у которых первый заказ был более 7-ми месяцев назад
DELETE FROM temporary_users WHERE id_o = 2 AND o_date < '2016-10-01';

-- смотрим на результат, осталось 274962 строки
DESCRIBE temporary_users;
SELECT COUNT(*) FROM temporary_users;
-- создаём таблицу, в которую сложим только всех, у кого есть 1 заказ, но он сделан за полгода
-- а из покупателей с двумя заказами, сохраним толлько тех, у кого разница между двумя заказами не больше 60-ти дней
-- таблицу заполним данными через процедуру
DROP TABLE IF EXISTS users_with_one_or_two_orders;
CREATE TABLE users_with_one_or_two_orders (user_id INT, price DOUBLE, o_date DATE);

DELIMITER $$
DROP PROCEDURE IF EXISTS insert_to_users_with_one_or_two_orders$$
CREATE PROCEDURE insert_to_users_with_one_or_two_orders()
BEGIN
	DECLARE user_id INT;
	DECLARE price DOUBLE;
	DECLARE id_o BIGINT;
	DECLARE o_date MEDIUMTEXT;
	DECLARE is_end INT DEFAULT 0;
	DECLARE curcat CURSOR FOR SELECT * FROM temporary_users;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET is_end = 1;

	OPEN curcat;
		cyc: LOOP
			FETCH curcat INTO user_id, price, id_o, o_date;
			IF is_end = 1 THEN
				LEAVE cyc;
			END IF;
			IF LENGTH(o_date) < 11 OR TIMESTAMPDIFF(
				DAY, 
				SUBSTRING_INDEX(o_date, ',', 1), 
				SUBSTRING_INDEX(o_date, ',', -1)) < 60 THEN
				INSERT INTO users_with_one_or_two_orders VALUES(
					user_id,
					price,
					CONVERT(SUBSTRING_INDEX(o_date, ',', -1), DATE));
			END IF;
		END LOOP cyc;
	CLOSE curcat;
END$$
DELIMITER ;

CALL insert_to_users_with_one_or_two_orders;

-- ну вот и осталось у нас 268989 контрольных строк
SELECT COUNT(*) FROM users_with_one_or_two_orders;

-- СЧИТАЕМ:
-- в сутки в апреле 2017-го они приносили в среднем 3 228 581.11, а это если * 30 =  98 657 433,30 денег в месяц
-- сумма каждого заказа по дням для 1-2-хзаказочников в апреле 2017-го
DROP TEMPORARY TABLE IF EXISTS average_daily_check_for_1_2_orders;
CREATE TEMPORARY TABLE average_daily_check_for_1_2_orders
	SELECT SUM(price) AS s 
	FROM users_with_one_or_two_orders 
	WHERE o_date BETWEEN '2017-04-01' AND '2017-04-30' 
	GROUP BY DAY(o_date);
SELECT 
	ROUND(AVG(s), 2) AS `1-2-заказники в апреле день тратили`, 
	ROUND(AVG(s), 2) * 30 AS `а это они в месяц такие` 
FROM average_daily_check_for_1_2_orders;

-- а вот те, кто до мая сделал 3+ заказов в апреле 2017-го, это 36 632 163,80 денег
DROP TEMPORARY TABLE IF EXISTS average_daily_check_for_3_plus_orders;
CREATE TEMPORARY TABLE average_daily_check_for_3_plus_orders
	SELECT SUM(price) AS s 
	FROM table_for_dz3 
	WHERE o_date BETWEEN '2017-04-01' AND '2017-04-30' 
	GROUP BY user_id HAVING 
	COUNT(*) >= 3;
SELECT 
	ROUND(SUM(s), 2) AS `3-хзаказники потратили в апреле 17-го` 
FROM average_daily_check_for_3_plus_orders;


-- ИТОГО:
-- линейным прогнозом берём заказы наших отфильтрованных 1-2-заказников - их сутку в апреле 2017-го
-- 3228581.11
-- умножаем на 30 дней:
SELECT 3228581.11 * 30;
-- получаем 96857433.30 денег
-- прибавляем к ним деньгу тех, кто сделал в апреле 2017-го 3+ заказа, это у нас:
-- 36632136.8
-- получаем 
SELECT 96857433.30 + 36632136.8;
-- 133489570.10 - это прогноз на май 2017-го "постоянной" активной базы
-- добавим к прогнозу приростом коэффициент новых в 2016-м году, подсчитанный в самом начале (63.5%), получим:
SET @predict := (SELECT ROUND(133489570.10 * 1.635, 2));
SELECT @predict `прогноз`;

-- сверим с фактическими данными за май 2017-го, которые у нас на самом-то на деле есть
SELECT @predict `прогноз`, @actual_values `факт`, ROUND(@predict / @actual_values * 100, 2) `%`;

-- перемахнули в прогнозе всего на 1.47%, ай да мы


