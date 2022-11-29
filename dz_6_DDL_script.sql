/*
Создать структуру БД турфирмы (можно в экселе, как я показываю на занятиях).
Что должно содержаться: кто куда летит, когда, какая оплата, может лететь группа, могут быть пересадки на рейсах, 
какая страна или страны, какие города и отели, звездность отеля, тип питания и комнат, данные о пассажирах, 
необходимость виз, ограничения, цель поездки, канал привлечения пользователя, бонусы и промокода и т.д.
Что получится - присылайте)
 */

-- ну вот набросал структура БД турфирмы, оттолкнувшись от билета, в ней таблицы:
-- 1) user_acquisition_channel - канал привлечения
-- 2) clients - клиенты
-- 3) name_of_the_group_of_clients - таблица на случай, если летит группа
-- 4) clients_name_of_the_group_of_clients - связка один-ко-многим пассажир-группа
-- 5) countries - страны
-- 6) airport_name - аэропорты
-- 7) countries_airport_name - связка один-ко-многим страны-аэропорты
-- 8) payment_methods - способы оплаты
-- 9) transfer - если предполагается пересадка
-- 10) cities - города
-- 11) food_types - типы питания
-- 12) number_of_rooms - количество комнат
-- 13) room_types - типы комнат
-- 14) hotel - гостиницы
-- 15) photo_bank - фотобанк
-- 16) list_of_tours - список туров
-- 17) photo_bank_list_of_tours - связка один-ко многим фото к туру
-- 18) bonus_programs - бонусные программы
-- 19) ticket - билет
-- 20) payment_methods_ticket - связка один-ко многим билет и способы его оплаты (вдруг их будет несколько)
-- 21) ticket_status - статус билета (тура)
-- 22) ticket_bonus_programs - связка один-ко-многим билет-бонусная программа


DROP DATABASE IF EXISTS databases_for_analysts_dz6;
CREATE DATABASE databases_for_analysts_dz6;
USE databases_for_analysts_dz6;

DROP TABLE IF EXISTS user_acquisition_channel;
CREATE TABLE user_acquisition_channel(
	id INT,
	name CHAR COMMENT 'названия каналов',
	
	INDEX(id)
) COMMENT 'каналы привлечения';


DROP TABLE IF EXISTS clients;
CREATE TABLE clients(
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
	firstname VARCHAR(100) NOT NULL COMMENT 'имя',
	lastname VARCHAR(100) COMMENT 'фамилия',
	phone BIGINT UNSIGNED UNIQUE NOT NULL COMMENT 'телефон',
	email VARCHAR(100) UNIQUE COMMENT 'почта',
	address TEXT COMMENT 'адрес',
	comment TEXT DEFAULT NULL COMMENT 'комментарий',
	created_at DATETIME DEFAULT NOW() COMMENT 'дата регистрации пассажира',
	updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP COMMENT 'дата изменения данных о пассажире',
	user_acquisition_channel INT COMMENT 'канал привлечения',
	
	CONSTRAINT sh_phone_check CHECK (REGEXP_LIKE(phone, '^[0-9]{11}$')),
	CONSTRAINT sh_email_check CHECK (REGEXP_LIKE(email, '^((([0-9A-Za-z]{1}[-0-9A-z\.]{0,30}[0-9A-Za-z]?)|([0-9А-Яа-я]{1}[-0-9А-я\.]{0,30}[0-9А-Яа-я]?))@([-A-Za-z]{1,}\.){1,}[-A-Za-z]{2,})$')),
	CONSTRAINT fk_user_acquisition_channel FOREIGN KEY (user_acquisition_channel) REFERENCES user_acquisition_channel(id) ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT 'клиенты-пассажиры';


DROP TABLE IF EXISTS name_of_the_group_of_clients;
CREATE TABLE name_of_the_group_of_clients(
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name VARCHAR(200) COMMENT 'названия групп',
	
	INDEX (id)
) COMMENT 'на случай если летит группа, то надо же её как-то назвать';


DROP TABLE IF EXISTS clients_name_of_the_group_of_clients;
CREATE TABLE clients_name_of_the_group_of_clients(
	id_group BIGINT UNSIGNED NOT NULL,
	id_client BIGINT UNSIGNED NOT NULL,
	
	CONSTRAINT fk_id_group_p_g FOREIGN KEY (id_group) REFERENCES name_of_the_group_of_clients(id),
	CONSTRAINT fk_id_client_p_g FOREIGN KEY (id_client) REFERENCES clients(id)
) COMMENT 'связка один-ко-многим пассажир-группа';


DROP TABLE IF EXISTS countries;
CREATE TABLE countries(
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name VARCHAR(200) COMMENT 'название',
	
	INDEX (id)
) COMMENT 'страны';


DROP TABLE IF EXISTS airport_name;
CREATE TABLE airport_name(
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name VARCHAR(200) COMMENT 'название',
	
	INDEX (id)
) COMMENT 'аэропорт';


DROP TABLE IF EXISTS countries_airport_name;
CREATE TABLE countries_airport_name(
	id_countries BIGINT UNSIGNED NOT NULL,
	id_airport_name BIGINT UNSIGNED NOT NULL,
	
	CONSTRAINT fk_id_countries FOREIGN KEY (id_countries) REFERENCES countries(id),
	CONSTRAINT fk_id_airport_name FOREIGN KEY (id_airport_name) REFERENCES airport_name(id)
) COMMENT 'один-ко-многим страна-аэропорт';


DROP TABLE IF EXISTS payment_methods;
CREATE TABLE payment_methods(
	id INT,
	name VARCHAR(100) COMMENT 'названия способов',
	
	INDEX(id)
) COMMENT 'способы оплаты';


DROP TABLE IF EXISTS transfer;
CREATE TABLE transfer(
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
	transfer_in_the_country BIGINT UNSIGNED NOT NULL,
	transfer_in_the_airport BIGINT UNSIGNED NOT NULL,
	
	INDEX (id),
	CONSTRAINT fk_transfer_in_the_country FOREIGN KEY (transfer_in_the_country) REFERENCES countries(id),
	CONSTRAINT fk_transfer_in_the_airport FOREIGN KEY (transfer_in_the_airport) REFERENCES airport_name(id)
) COMMENT 'если предполагается пересадка';


DROP TABLE IF EXISTS cities;
CREATE TABLE cities(
	id_city INT,
	name VARCHAR(200) COMMENT 'название',
	
	INDEX (id_city)
) COMMENT 'названия городов';


DROP TABLE IF EXISTS food_types;
CREATE TABLE food_types(
	id INT UNSIGNED NOT NULL AUTO_INCREMENT,
	name VARCHAR(100) COMMENT 'название',
	description TEXT COMMENT 'описание',
	
	INDEX (id)
) COMMENT 'типы питания';


DROP TABLE IF EXISTS number_of_rooms;
CREATE TABLE number_of_rooms(
	number_of_rooms INT COMMENT 'количество',
	
	INDEX (number_of_rooms)
) COMMENT 'количество комнат';


DROP TABLE IF EXISTS room_types;
CREATE TABLE room_types(
	id INT UNSIGNED NOT NULL AUTO_INCREMENT,
	title VARCHAR(100) COMMENT 'краткое название',
	number_of_rooms INT COMMENT 'кол-во комнат',
	description TEXT COMMENT 'описание',
	
	INDEX(id),
	CONSTRAINT fk_number_of_rooms FOREIGN KEY (number_of_rooms) REFERENCES number_of_rooms(number_of_rooms) ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT 'типы комнат';


DROP TABLE IF EXISTS hotel;
CREATE TABLE hotel(
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(300) COMMENT 'название',
	city INT COMMENT 'город',
	address TEXT COMMENT 'адрес',
	hotel_category ENUM ('not category', '*', '**', '***', '****', '*****') COMMENT 'кол-во звёзд',
	food_type INT UNSIGNED NOT NULL COMMENT 'тип еды',
	room_types INT UNSIGNED NOT NULL COMMENT 'тип комнат',
	description TEXT DEFAULT NULL COMMENT 'описание',
	
	CONSTRAINT fk_city FOREIGN KEY (city) REFERENCES cities(id_city) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_food_type FOREIGN KEY (food_type) REFERENCES food_types(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_room_types FOREIGN KEY (room_types) REFERENCES room_types(id) ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT 'гостиница';


DROP TABLE IF EXISTS photo_bank;
CREATE TABLE photo_bank(
	id BIGINT,
	photo_link VARCHAR(200) COMMENT 'ссылка на фото',
	
	INDEX (id)
) COMMENT 'фотобанк';


DROP TABLE IF EXISTS list_of_tours;
CREATE TABLE list_of_tours(
	id INT,
	title VARCHAR(350) COMMENT 'название туров',
	description TEXT COMMENT 'описание',
	special_notes TEXT COMMENT 'особые отметки',
	a_photo BIGINT DEFAULT NULL COMMENT 'фото',
	
	INDEX (id)
) COMMENT 'список туров';


DROP TABLE IF EXISTS photo_bank_list_of_tours;
CREATE TABLE photo_bank_list_of_tours(
	id_photo_bank BIGINT,
	id_tour INT,
	
	CONSTRAINT fk_id_photo_bank FOREIGN KEY (id_photo_bank) REFERENCES photo_bank(id),
	CONSTRAINT fk_id_tour FOREIGN KEY (id_tour) REFERENCES list_of_tours(id)
) COMMENT 'один-ко-многим фото к турам';


DROP TABLE IF EXISTS bonus_programs;
CREATE TABLE bonus_programs(
	id BIGINT,
	title VARCHAR(250) COMMENT 'имя программы',
	description TEXT DEFAULT NULL COMMENT 'описание',
	
	INDEX (id)
) COMMENT 'список бонусных программ';


DROP TABLE IF EXISTS ticket;
CREATE TABLE ticket(
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	name_travel INT COMMENT 'название тура',
	ticket_issue_date DATETIME DEFAULT NOW() COMMENT 'время оформления билета',
	date_and_time_of_flight DATETIME NOT NULL COMMENT 'дата и время полёта',
	client_id BIGINT UNSIGNED NOT NULL COMMENT 'клиент',
	id_countries BIGINT UNSIGNED NOT NULL COMMENT 'в страну',
	id_airport_name BIGINT UNSIGNED NOT NULL COMMENT 'в аэропорт',
	is_there_a_transplant BIGINT UNSIGNED DEFAULT NULL COMMENT 'есть ли пересадка',
	need_for_a_visa ENUM('yes', 'no') COMMENT 'нужна ли виза',
	restrictions TEXT DEFAULT NULL COMMENT 'ограничения',
	purpose_of_travel TEXT DEFAULT NULL COMMENT 'цель поездки',
	hotel BIGINT UNSIGNED NOT NULL COMMENT 'гостиница',
	price DECIMAL(10, 2) NOT NULL COMMENT 'цена',
	bonus_program BIGINT DEFAULT NULL COMMENT 'бонусная программа',
	payment_methods BIGINT UNSIGNED NOT NULL COMMENT 'способ оплаты',
	
	CONSTRAINT fk_client_id FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_id_countries_ticket FOREIGN KEY (id_countries) REFERENCES countries(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_id_airport_name_ticket FOREIGN KEY (id_airport_name) REFERENCES airport_name(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_hotel FOREIGN KEY (hotel) REFERENCES hotel(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_name_travel FOREIGN KEY (name_travel) REFERENCES list_of_tours(id) ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT 'билет';


DROP TABLE IF EXISTS payment_methods_ticket;
CREATE TABLE  payment_methods_ticket(
	id_payment_methods INT,
	id_ticket BIGINT UNSIGNED NOT NULL,
	
	CONSTRAINT fk_pt_id_payment_methods FOREIGN KEY (id_payment_methods) REFERENCES payment_methods(id),
	CONSTRAINT fk_pt_id_ticket FOREIGN KEY (id_ticket) REFERENCES ticket(id)
) COMMENT 'привязка один-ко-многим тур-оплата';


DROP TABLE IF EXISTS ticket_status;
CREATE TABLE ticket_status(
	id_ticket BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
	status ENUM('новый', 'в работе', 'завершён', 'отменён') COMMENT  'статус',
	
	CONSTRAINT fk_ts_id_ticket FOREIGN KEY (id_ticket) REFERENCES ticket(id)
) COMMENT 'статус билета (тура)';


DROP TABLE IF EXISTS ticket_bonus_programs;
CREATE TABLE ticket_bonus_programs(
	id_ticket BIGINT UNSIGNED NOT NULL,
	id_bonus_program BIGINT,

	CONSTRAINT fk_id_bonus_program FOREIGN KEY (id_bonus_program) REFERENCES bonus_programs(id),
	CONSTRAINT fk_id_ticket FOREIGN KEY (id_ticket) REFERENCES ticket(id)
) COMMENT 'привязка один-ко-многим';


