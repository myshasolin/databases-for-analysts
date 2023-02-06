/*
Даны 2 таблицы:
Таблица клиентов clients, в которой находятся данные по карточному лимиту каждого клиента
clients
id_client (primary key) number,
limit_sum number

transactions
id_transaction (primary key) number,
id_client (foreign key) number,
transaction_date number,
transaction_time number,
transaction_sum number

Написать текст SQL-запроса, выводящего количество транзакций, сумму транзакций, среднюю сумму транзакции и дату и время первой транзакции для каждого клиента
Найти id пользователей, кот использовали более 70% карточного лимита
 */

USE databases_for_analysts;

-- по условию задания тип у даты и времени почему-то предполагается числовой, что странно, но раз так, то создадим таблицу с числовыми типами,
-- а потом "на лету" в SELECT-запросе их будем переделывать. Там же и дату со временем соберём в один столбец, 
-- переделав её из числового типа BIGINT в календарный DATETIME

-- создадим таблицы эти по условиям задания со всеми положенными и прописанными в дз PRIMARY KEY и FOREIGN KEY
DROP TABLE IF EXISTS clients;
CREATE TABLE clients (
	id_client BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	limit_sum BIGINT
);

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
	id_transaction BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	id_client BIGINT UNSIGNED NOT NULL,
	transaction_date BIGINT,
	transaction_time BIGINT,
	transaction_sum BIGINT,
	CONSTRAINT fk_id_client FOREIGN KEY (id_client) REFERENCES clients(id_client) ON DELETE CASCADE ON UPDATE CASCADE
);

-- заполним несколько строк в таблицах. У кого-то будет 0 транзакций, а у кого-то аж 4 шт.
INSERT INTO clients (limit_sum) VALUES (500), (1000), (25000), (50), (100), (4000), (60000), (200), (1000), (100000), (500), (1100), (2200), (70000), (600), (8000), (1500), (900), (15);
INSERT INTO transactions (id_client, transaction_date, transaction_time, transaction_sum) VALUES 
	(1, 20171011, 1222, 250), (1, 20171012, 2315, 50), (3, 20171012, 1005, 560), (4, 20171013, 1101, 100), (5, 20171014, 1856, 1500), (6, 20171014, 1750, 800), (4, 20171015, 0615, 23120),
	(8, 20171016, 1433, 80), (8, 20171018, 0202, 15500), (10, 20171025, 0755, 900), (1, 20171101, 2141, 7524), (12, 20171101, 1602, 11520), (13, 20171120, 1131, 1400),
	(14, 20171120, 0946, 9326), (10, 20171121, 1012, 5255),	(4, 20171122, 0155, 2000), (17, 20171123, 2247, 1478),	(18, 20171202, 1741, 6999),	(18, 20171203, 1936, 800),
	(19, 20171203, 0822, 25400), (14, 20171205, 2311, 155), (5, 20171206, 1132, 11230), (9, 20171209, 1420, 7450), (2, 20171211, 0922, 4122), (14, 20171211, 2241, 9630),
	(1, 20171221, 0353, 450), (10, 20171222, 0955, 750), (3, 20171223, 1432, 11210), (5, 20171225, 1759, 9850);
	
-- посмотрим на то безобразие, что имеем
SELECT 
	c.id_client, 
	c.limit_sum, 
	t.id_transaction, 
	t.transaction_date, 
	t.transaction_time, 
	t.transaction_sum 
FROM clients c
LEFT JOIN transactions t  ON c.id_client = t.id_client;

-- ну и выведем то, что там требовалось по заданию, а именно:
-- id_client - id покупателя
-- number of transactions - количество транзакций у покупателя
-- amount of transactions - сумма транзакций покупателя
-- average amount of transactions - средняя сумма транзакций покупателя
-- transaction date and time - дата и время первой транзакции покупателя
SELECT 
	c.id_client,
	COUNT(t.id_transaction) AS `number of transactions`,
	SUM(t.transaction_sum) AS `amount of transactions`,
	ROUND(AVG(t.transaction_sum)) AS `average amount of transactions`,
	MIN(
		STR_TO_DATE(
			CONCAT(
				CONVERT(transaction_date, CHAR), 
				' ',
				(CASE
					WHEN CHAR_LENGTH(CONVERT(transaction_time, CHAR)) = 3 THEN 
						CONCAT('0', CONVERT(transaction_time, CHAR))
					ELSE 
						CONVERT(transaction_time, CHAR)
				END)), 
			'%Y%m%d %H%i')
	) AS `transaction date and time`
FROM clients c
LEFT JOIN transactions t 
ON c.id_client = t.id_client
GROUP BY c.id_client ;


-- Найти id пользователей, кот использовали более 70% карточного лимита
-- ну вот, выводим:
-- 1) users who have spent more than 70% of the limit - это пользователь
-- 2) used limit in percent - а это его перебор по лимиту в процентах (за лимит считаю текущий остаток на карте)
SELECT 
	clients.id_client `users who have spent more than 70% of the limit`, 
	ROUND((transaction_sum/limit_sum)*100) `used limit in percent`
FROM 
	(SELECT 
		id_client, 
		limit_sum 
	FROM clients) clients
	JOIN
	(SELECT 
		id_client, 
		SUM(transaction_sum) transaction_sum 
	FROM transactions 
	GROUP BY id_client) transactions
	ON clients.id_client = transactions.id_client
HAVING `used limit in percent` > 70;


-- готовые 2 таблицы выгрузил в Excel под названием "dz_5_сводные из SQL.xlsx"

