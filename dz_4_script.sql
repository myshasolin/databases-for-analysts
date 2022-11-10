USE databases_for_analysts;

DROP TABLE IF EXISTS table_for_dz4;
CREATE TABLE table_for_dz4 SELECT * FROM table_for_dz2;

/*
Главная задача: сделать RFM-анализ на основе данных по продажам за 2 года (из предыдущего дз).
​
Что делаем:
1. Определяем критерии для каждой буквы R, F, M (т.е. к примеру, 
	R – 3 для клиентов, которые покупали <= 30 дней от последней даты в базе, 
	R – 2 для клиентов, которые покупали > 30 и менее 60 дней от последней даты в базе и т.д.)
2. Для каждого пользователя получаем набор из 3 цифр (от 111 до 333, где 333 – самые классные пользователи)
3. Вводим группировку, к примеру, 333 и 233 – это Vip, 1XX – это Lost, остальные Regular ( можете ввести боле глубокую сегментацию)
4. Для каждой группы из п. 3 находим кол-во пользователей, кот. попали в них и % товарооборота, которое они сделали на эти 2 года.
5. Проверяем, что общее кол-во пользователей бьется с суммой кол-во пользователей по группам из п. 3 
(если у вас есть логические ошибки в создании групп, у вас не собьются цифры). То же самое делаем и по деньгам.
6. Результаты присылаем.
Доп задание: получить типовые коэффициенты для когорт (первые 12 мес жизни)
*/


/*
делаем.
Показатели RFM  у нас будут:
R - Recency - давность
R1 - заказы больше 90 дней
R2 - заказы от 46 до 90 дней
R3 - заказы до 45 дней
F - Frecuency - частота 
F1 - 1 заказ
F2 - от 2-х до 4-х заказов
F3 - от 5-ти заказов
M - Monetary - сумма
M1 - сумма менее 10 000
M2 - сумма от 10 000 до 20 000
M3 - сумма от 20 000

в VIP определим RFM = 333, 233 и 323
в LOST = 1__, т.е. всех начинающихся с единицы
в REGULAR - всех остальных
*/

-- всего уникальных пользователей 1 011 757 шт.:
SET @total_users_in_the_database := (SELECT COUNT(DISTINCT user_id) FROM table_for_dz4);
SELECT @total_users_in_the_database;

-- вся сумма заказов 4 491 109 425 денег:
SET @total_prices_in_the_database := (SELECT ROUND(SUM(price)) FROM table_for_dz4);
SELECT @total_prices_in_the_database;


/*
собираем один SELECT-запрос, в котором получим следующие столбцы: 
1) rfm_category - RFM-категорию
2) count - количество уникальных пользователей в ней 
3) % count - % пользователей в каждой категории 
4) status - статус пользователей в зависимости от RFM-категории
5) sum_price - сумма товарооборота пользователей в зависимости от RFM-категории
6) % sum_price - % товарооборота пользователей в зависимости от RFM-категории
7) sum from status - сумма товарооборота пользователей в зависимости от статуса пользователей
8) % sum from status - % товарооборота пользователей в зависимости от статуса пользователей
 
7 и 8 столбцы - оконная функция, поэтому значения для одинаковых статусов проставлены одинаковые (что логично), в сумме 3 таких статуса дают 100%
получившуюся таблицу выгрузил в Excel на лист "сводная"
 */

SELECT 
	*,
	SUM(sum_price) OVER(PARTITION BY status) AS `sum from status`,
	SUM(`% sum_price`) OVER(PARTITION BY status) AS `% from status`
FROM
	(SELECT 
		rfm_category,
		COUNT(DISTINCT `table`.user_id) AS `count`,
		ROUND(SUM(COUNT(DISTINCT `table`.user_id)) OVER(PARTITION BY rfm_category) / @total_users_in_the_database * 100, 2) AS `% count`,
		(CASE
			WHEN rfm_category = '333' OR rfm_category = '233' OR rfm_category = '323' THEN 'VIP'
			WHEN rfm_category LIKE '1%' THEN 'LOST'
			ELSE 'REGULAR'
		END
		) AS status,
		ROUND(SUM(`price`)) AS sum_price,
		ROUND(SUM(`price`) / @total_prices_in_the_database * 100, 3) AS `% sum_price` 
	FROM(
		SELECT 
			rfm.user_id,
			rfm.`sum` AS `price`,
			CONCAT(
				(CASE
					WHEN days BETWEEN 0 AND 45 THEN '3'
					WHEN days BETWEEN 46 AND 90 THEN '2'
					ELSE '1' 
				END),
				(CASE
					WHEN count_orders >= 5 THEN '3'
					WHEN count_orders BETWEEN 2 AND 4 THEN '2'
					ELSE '1' 
				END),
				(CASE 
					WHEN `sum` > 20000 THEN '3'
					WHEN `sum` BETWEEN 10000 AND 20000 THEN '2'
					ELSE '1' 
				END)
			) AS rfm_category
		FROM (SELECT
				user_id,
				TIMESTAMPDIFF(DAY, MAX(o_date), '2017-12-31') AS days,
				COUNT(id_o) AS count_orders,
				SUM(price) AS `sum`
			FROM table_for_dz4
			GROUP BY user_id) AS rfm) AS `table`
	GROUP BY `table`.rfm_category) AS rfm
ORDER BY `% from status` DESC, `% count` DESC;



-- 5. Проверяем и убеждаемся в том, что общее кол-во пользователей бьётся с суммой кол-ва пользователей по группам из п. 3, а значит всё норм
SELECT 
	SUM(s.`count`) AS `пользователей в RFM`,
	@total_users_in_the_database AS `всего пользователей в базе`,
	(CASE WHEN (SELECT SUM(s.`count`) = (SELECT COUNT(DISTINCT user_id) FROM table_for_dz4)) = 1 THEN 'да' ELSE 'нет'END) AS `совпадает ли кол-во?`
FROM
	(SELECT rfm_category, COUNT(DISTINCT `table`.user_id) AS `count` FROM(
		SELECT user_id,	CONCAT(
			(CASE WHEN days BETWEEN 0 AND 45 THEN '3' WHEN days BETWEEN 46 AND 90 THEN '2' ELSE '1' END),
			(CASE WHEN count_orders >= 5 THEN '3' WHEN count_orders BETWEEN 2 AND 4 THEN '2' ELSE '1' END),
			(CASE WHEN `sum` > 20000 THEN '3' WHEN `sum` BETWEEN 10000 AND 20000 THEN '2' ELSE '1' END)) AS rfm_category
		FROM (SELECT user_id, TIMESTAMPDIFF(DAY, MAX(o_date), '2017-12-31') AS days, COUNT(id_o) AS count_orders,	SUM(price) AS `sum`
			FROM table_for_dz4 GROUP BY user_id) AS rfm) AS `table`
	GROUP BY `table`.rfm_category) AS s;


-- Доп задание: получить типовые коэффициенты для когорт (первые 12 мес жизни)

/*
вот так одним запросом получим сразу:
1) cohort - когорту (критерий когорты - месяц, в который был совершён первый заказ)
2) time interval - разбивка каждой которты на всё время её жизни (от 24-х месяцев для когорты 201601 до 1-го месяца для когорты 201712)
3) sum price - сумма, которую принесла когорта в каждый месяц своей жизни

получившуюся таблицу выгрузил в Excel на лист "когорты", построил по ней сводные таблицы в виде треугольной матрицы с коэффициентами по сумме и процентам
*/

SELECT 
	cohort,
	DATE_FORMAT(o_date, '%Y%m') AS `time interval`,
	SUM(price) AS `sum price`
FROM
	(SELECT 
		date_and_price.price AS price, 
		date_and_price.o_date AS o_date,
		cohorts.cohort AS cohort
	FROM table_for_dz4 AS date_and_price
	JOIN  
	(SELECT 
		user_id,
		DATE_FORMAT(MIN(o_date), '%Y%m') AS cohort
	FROM table_for_dz4
	GROUP BY user_id) AS cohorts
	ON date_and_price.user_id = cohorts.user_id) AS `table`
GROUP BY cohort, `time interval`
ORDER BY cohort, `time interval`;

