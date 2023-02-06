/*
Задание 2:
По кратинке из матриеалов напистаь запрос "Найти пользователей, у которых был хотя бы один заказ, весом больше 10 кг"
 */

-- 1 шаг. Наделаем для примера технических табличек и заполних их инфой

DROP DATABASE IF EXISTS databases_for_analysts_dz6_2;
CREATE DATABASE databases_for_analysts_dz6_2;
USE databases_for_analysts_dz6_2;

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
	id_o INT,
	id_u INT,
	o_date DATETIME DEFAULT NOW()
);

DROP TABLE IF EXISTS basket;
CREATE TABLE basket(
	id_b INT,
	id_o INT,
	id_prod INT,
	q INT,
	price_for_one DOUBLE
);

DROP TABLE IF EXISTS property;
CREATE TABLE property(
	id_prop INT,
	name VARCHAR(100)
);

DROP TABLE IF EXISTS prop_value;
CREATE TABLE prop_value(
	id_pv INT,
	id_prod INT,
	id_prop INT,
	value VARCHAR(100)
);


INSERT INTO orders (id_o, id_u) VALUES 
(1, 1), (2, 2), (3, 1), (4, 3), (5, 4), (6, 5), (7, 6), (8, 6), (9, 7), (10, 8), (11, 5), (12, 7);

INSERT INTO basket (id_b, id_o,	id_prod, q,	price_for_one) VALUES
(1, 1, 1, 5, 9900), (1, 1, 2, 1, 999), (1, 1, 4, 2, 9999),
(2, 2, 5, 2, 6999),
(3, 3, 5, 1, 6999), (3, 3, 1, 1, 9900), (3, 3, 7, 2, 199),
(4, 4, 2, 1, 999), (4, 4, 4, 3, 999), (4, 4, 9, 2, 599),
(5, 5, 8, 1, 39), (5, 5, 7, 2, 99), (5, 5, 4, 1, 9999),
(6, 6, 8, 4, 39), (6, 6, 3, 1, 999),
(7, 7, 10, 2, 399), (7, 7, 2, 1, 999), (7, 7, 9, 1, 599),
(8, 8, 5, 1, 6999),
(9, 9, 8, 1, 39), (9, 9, 6, 1, 888), (9, 9, 10, 2, 399),
(10, 10, 10, 1, 399), (10, 10, 8, 1, 39),
(11, 11, 6, 1, 888), (11, 11, 1, 2, 9900), (11, 11, 5, 1, 5999), (11, 11, 4, 2, 999), (11, 11, 10, 1, 399), (11, 11, 9, 1, 599), (11, 11, 2, 2, 999);

INSERT INTO property (id_prop, name) VALUES
(1, 'вес, кг'), (2, 'цвет'), (3, 'длина, м');

INSERT INTO prop_value (id_pv, id_prod, id_prop, value) VALUES
(1, 1, 1, '4'), (1, 1, 2, 'красный'), (1, 1, 3, '100'),
(2, 2, 1, '1'), (2, 2, 2, 'оранжевый'), (2, 2, 3, '200'),
(3, 3, 1, '1.5'), (3, 3, 2, 'желтый'), (3, 3, 3, '300'),
(4, 4, 1, '3'), (4, 4, 2, 'зелёный'), (4, 4, 3, '350'),
(5, 5, 1, '0.4'), (5, 5, 2, 'голубой'), (5, 5, 3, '400'),
(6, 6, 1, '0.5'), (6, 6, 2, 'синий'), (6, 6, 3, '500'),
(7, 7, 1, '2'), (7, 7, 2, 'фиолетовый'), (7, 7, 3, '600'),
(8, 8, 1, '3'), (8, 8, 2, 'вери пери'), (8, 8, 3, '700'),
(9, 9, 1, '5'), (9, 9, 2, 'сиреневый'), (9, 9, 3, '800'),
(10, 10, 1, '1'), (10, 10, 2, 'кислотный'), (10, 10, 3, '900');


-- 2 шаг. Вот он, собственно, SELECT-запос
-- Мы просто джойним все таблицы (orders, basket, prop_value и property) и работаем только с теми колонками в каждой, что нам нужны. 
-- В итоге выводим только orders.id_u - покупателей именно из таблицы orders, а значит точно совершивших заказ.
-- В условии WHERE у нас фильтрация по колонке property.id_prop = 1, т.е. рассматриваем только характеристики веса, отбросив остальные, 
-- а в HAVING  у нас SUM(вес товара * его кол-во в заказе) >= 10, за счёт чего получаем только нужный нам вес заказа. 
-- С помощью DISTINCT избавляемся от дублей (это на случай, если один и тот же покупатель сделал несколько заказов с весом выше 10 кг.)
-- Ну и вот такой код получается:

SELECT DISTINCT
	o.id_u
FROM orders o
JOIN basket b ON o.id_o = b.id_o
JOIN prop_value pv ON pv.id_prod = b.id_prod
JOIN property p ON p.id_prop = pv.id_prop
WHERE p.id_prop = 1
GROUP BY o.id_o
HAVING SUM(pv.value * b.q) >= 10;

