USE databases_for_analysts;

/*
ДЗ делаем по бд orders
В качестве ДЗ сделаем карту поведения пользователей. Мы обсуждали, что всех пользователей можно разделить, к примеру, на New (совершили только 1 покупку), 
Regular (совершили 2 или более на сумму не более стольки-то), Vip (совершили дорогие покупки и достаточно часто), 
Lost (раньше покупали хотя бы раз и с даты последней покупки прошло больше 3 месяцев). 
Вся база должна войти в эти гурппы (т.е. каждый пользователь должен попадать только в одну из этих групп).
Задача:
1. Уточнить критерии групп New,Regular,Vip,Lost
2. По состоянию на 1.01.2017 понимаем, кто попадает в какую группу, подсчитываем кол-во пользователей в каждой.
3. По состоянию на 1.02.2017 понимаем, кто вышел из каждой из групп, а кто вошел.
4. Аналогично смотрим состояние на 1.03.2017, понимаем кто вышел из каждой из групп, а кто вошел.
5. В итоге делаем вывод, какая группа уменьшается, какая увеличивается и продумываем, в чем может быть причина.
Присылайте отчет в pdf
 */

-- начнём работать с очищенной от выбросов таблицы со 2-го дз, 
-- создадим на её основе в процедуре временные таблицы, каждая под свою категорию, в ней же будем проводить проверку на корректность 
-- собираемых данных и выводить на экран результат проверки
-- собираем данные через временные таблицы мы будем ещё и потому, что потом в работе к этим данным всегда можно будет отдельно обращаться. А что, а вдруг))
-- в цикле вызовем нашу процедуру ровно столько раз, на сколько месяцев хотим получить разбивку покупателей на категории
-- результат по месяцам сложим в отдельную таблицу table_for_dz8, а пока создадим её пустую, вот:
DROP TABLE IF EXISTS table_for_dz8;
CREATE TABLE table_for_dz8 (diapason VARCHAR(20), category VARCHAR(20), value INT);

-- а вот и основная процедура
DELIMITER //
DROP PROCEDURE IF EXISTS create_a_user_card//
CREATE PROCEDURE create_a_user_card (base_range VARCHAR(20))
BEGIN
	-- New - покупатели с 1-м заказом за последние 90 дней.
	DROP TEMPORARY TABLE IF EXISTS new_users;
	CREATE TEMPORARY TABLE new_users AS
	SELECT 
		COUNT(id_o) AS count_id_o,
		user_id,
		price,
		o_date, 
		TIMESTAMPDIFF(DAY, MAX(o_date), base_range) AS days,
		'new'
	FROM table_for_dz2
	WHERE o_date <= base_range
	GROUP BY user_id 
	HAVING count_id_o = 1 AND days < 91; 
	
	-- Regular - покупатели с 2+ заказами до 50000 р., у которых хотя бы 1 заказ был за последние 120 дней.
	DROP TEMPORARY TABLE IF EXISTS regular_users;
	CREATE TEMPORARY TABLE regular_users AS
	SELECT 
		COUNT(id_o) AS count_id_o,
		user_id,
		price,
		SUM(price) AS sum_price,
		o_date,
		TIMESTAMPDIFF(DAY, MAX(o_date), base_range) AS days,
		'regular'
	FROM table_for_dz2
	WHERE o_date <= base_range
	GROUP BY user_id 
	HAVING count_id_o > 1 AND price < 50000 AND days < 121;
	
	-- lost - потеряшки с 1 заказом больше 90 дней назад.
	DROP TEMPORARY TABLE IF EXISTS lost_users;
	CREATE TEMPORARY TABLE lost_users AS
	SELECT 
		COUNT(id_o) AS count_id_o,
		user_id,
		price,
		price AS sum_price,
		o_date, 
		TIMESTAMPDIFF(DAY, MAX(o_date), base_range) AS days,
		'lost'
	FROM table_for_dz2
	WHERE o_date <= base_range
	GROUP BY user_id 
	HAVING COUNT(*) = 1 AND days >= 91; 
	
	-- добавим к lost тех, у кого было > 1 заказа, но, увы, > 120-ти дней назад. 
	INSERT INTO lost_users
	SELECT 
		COUNT(id_o) AS count_id_o,
		user_id,
		price,
		SUM(price) AS sum_price,
		o_date,
		TIMESTAMPDIFF(DAY, MAX(o_date), base_range) AS days,
		'lost'
	FROM table_for_dz2
	WHERE o_date <= base_range
	GROUP BY user_id 
	HAVING count_id_o > 1 AND price < 50000 AND days >= 121;
	
	-- Vip - пользователи, совершившие больше 2-х дорогих заказов, но у которых среднее время между заказами больше 60-ти дней. 
	DROP TEMPORARY TABLE IF EXISTS vip_users;
	CREATE TEMPORARY TABLE vip_users AS
	SELECT 
		COUNT(id_o) AS count_id_o,
		user_id,
		price,
		SUM(price) AS sum_price,
		o_date,
		ROUND(TIMESTAMPDIFF(DAY, MIN(o_date), base_range)/(COUNT(id_o))-1) AS count_days,
		'vip'
	FROM table_for_dz2
	WHERE o_date <= base_range
	GROUP BY user_id 
	HAVING COUNT(*) > 1 AND price > 50000 AND count_days > 61;
	
	-- SuperVip - пользователи, совершившие больше 2-х дорогих заказов и у которых среднее время между заказами не больше 60-ти дней.
	DROP TEMPORARY TABLE IF EXISTS supervip_users;
	CREATE TEMPORARY TABLE supervip_users AS
	SELECT 
		COUNT(id_o) AS count_id_o,
		user_id,
		price,
		SUM(price) AS sum_price,
		o_date,
		ROUND(TIMESTAMPDIFF(DAY, MIN(o_date), base_range)/(COUNT(id_o))-1) AS count_days,
		'supervip'
	FROM table_for_dz2
	WHERE o_date <= base_range
	GROUP BY user_id 
	HAVING COUNT(*) > 1 AND price > 50000 AND count_days < 61;
	
	-- соединим все временные таблицы в одну под названием table_for_base_range
	DROP TABLE IF EXISTS table_for_base_range;
	CREATE TABLE table_for_base_range  AS
	SELECT * FROM(
	SELECT count_id_o, user_id, price AS sum_price, o_date, 'new' AS category FROM new_users
	UNION ALL
	SELECT count_id_o, user_id, sum_price, o_date, 'lost' FROM lost_users
	UNION ALL
	SELECT count_id_o, user_id, sum_price, o_date, 'regular' FROM regular_users
	UNION ALL
	SELECT count_id_o, user_id, sum_price, o_date, 'vip' FROM vip_users
	UNION ALL
	SELECT count_id_o, user_id, sum_price, o_date, 'supervip' FROM supervip_users) t;
	
	-- проверим количество строк и общую сумму у получившейся таблицы, они должны совпадать с уникальным количеством колупателенй и суммов в table_for_dz2
	SELECT 
		(SELECT COUNT(DISTINCT user_id) FROM table_for_dz2 WHERE o_date <= base_range) AS table_for_dz2, 
		(SELECT COUNT(*) FROM table_for_base_range) AS table_for_base_range,
		(CASE 
			WHEN (SELECT COUNT(DISTINCT user_id) FROM table_for_dz2 WHERE o_date <= base_range) = (SELECT COUNT(*) FROM table_for_base_range) THEN 
				'да' 
			ELSE 
				'нет' 
		END) AS 'количество строк совпадает?',
		CEILING((SELECT SUM(price) FROM table_for_dz2 WHERE o_date <= base_range)) AS sum_price_in_table_for_dz2, 
		CEILING((SELECT SUM(sum_price) FROM table_for_base_range)) AS sum_price_in_table_for_base_range,
		(CASE
			WHEN CEILING((SELECT SUM(price) FROM table_for_dz2 WHERE o_date <= base_range)) = CEILING((SELECT SUM(sum_price) FROM table_for_base_range)) THEN
				'да'
			ELSE
				'нет'
		END) AS 'сумма совпадает?';
	
	SELECT COUNT(category) FROM table_for_base_range GROUP BY category;
	
	-- заполняем данными итоговую таблицу table_for_dz8
	INSERT INTO table_for_dz8
	SELECT 
		base_range AS diapason,
		category,
		COUNT(user_id) AS `на @base_range`
	FROM table_for_base_range
	WHERE o_date <= base_range
	GROUP BY category;
END//
DELIMITER ;

-- в процедуру repeat_call передаём количество месяцев, стартуем с 31 января 2017-го, получая данные на конец месяца
-- и так в цикле прибавляем по месяцу и получаем на конец каждого всё новые и новые данные в таблицу table_for_dz8
-- запустим и соберём данные за полгода
DELIMITER //
DROP PROCEDURE IF EXISTS repeat_call//
CREATE PROCEDURE repeat_call()
BEGIN
	DECLARE i INT DEFAULT 6;
	DECLARE start_time VARCHAR(20);
	SET start_time = '2016-12-31';
	REPEAT
		SET start_time = start_time + INTERVAL 1 MONTH;
		CALL create_a_user_card(start_time);
		SET i = i-1;
	UNTIL i <= 0
	END REPEAT;
END//
DELIMITER ;

CALL repeat_call;

-- вот что получилось
SELECT 
	january.category AS category, 
	january.value AS `jan value`,
	february.value AS `feb value`,
	march.value AS `mar value`,
	april.value AS `apr value`,
	may.value AS `may value`,
	june.value AS `june value`,
	ROUND(((february.value/january.value -1)*100 + (march.value/february.value -1)*100 + (april.value/march.value -1)*100
	+ (may.value/april.value -1)*100 + (june.value/may.value -1)*100)/5, 2) AS `changes in indicators`
FROM table_for_dz8 AS january
JOIN table_for_dz8 AS february ON january.category = february.category
JOIN table_for_dz8 AS march ON january.category = march.category 
JOIN table_for_dz8 AS april ON january.category = april.category 
JOIN table_for_dz8 AS may ON january.category = may.category 
JOIN table_for_dz8 AS june ON january.category = june.category 
WHERE 
	MONTH(january.diapason) = 1 AND 
	MONTH(february.diapason) = 2 AND 
	MONTH(march.diapason) = 3 AND 
	MONTH(april.diapason) = 4 AND
	MONTH(may.diapason) = 5 AND
	MONTH(june.diapason) = 6;

/*
симпатичный графичек есть в Excel, а так бегло по категориям мы видим вот что:

- regular он на то и regular - эта категория оказалась одной из самых стабильных и за 6 месяцев практически не изменилась. Она пополняется новыми, которые через 
3 месяца в неё попадают. Неплохо было бы поработать над удержанием покупателей в regular, так как это достаточно стабильный сегмент покупателей и в нём много народа

- new - категория к началу июля снизилась на 6,62%, это связано с общим небольшим снижением кол-ва заказов (в особенности ближе к лету). Стоит обратить внимание на неё внимание, 
так как в марте было самое ощутимое падение новых, а март, вообще-то, это месяц в котором есть 8-е число, к этому дню можно было как-то нагнать новых покупателей

- при этом количество крупных заказов растёт, так как выросли категории vip и supervip на 12,4 и 5,85 % соответственно
это согласуется и с общим ростом магазина, который хорошо видно в ежемесячной разбивке данных по сумме заказов (делали в дз-2, код для получения такой разбивки ниже)

- ну а количество потеряшек (lost) ожидаемо увеличивается, за 6 месяцев категория выросла на 14,23% и продолжит расти, т.к. многие покупатели к какому-то времени 
туда отправляются, увы. Именно поэтому так важно стимулировать рост новых покупателей, я бы на этот момент обратил внимание, т.к. на випах далеко не уедешь, рискованно
*/


-- PS.: кусок из dz_2: сумму по месяцам можем получить так
SELECT 
	YEAR(o_date) AS `year`, 
	MONTH(o_date) AS `month`, 
	ROUND(AVG(price)) AS `avg`, 
	ROUND(SUM(price)) AS `sum` 
FROM table_for_dz2 
GROUP BY `year`, `month`;


