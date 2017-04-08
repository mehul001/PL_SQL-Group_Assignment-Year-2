--University Of Northampton -- Databases 2 -- Group Assignment -- PL/SQL
--Sam Patterson - 14436607
--Maciek Pawelkiewicz - 14412193
--Mehul Chamunda - 14406068
--Charlie Leedahm - 13429127

SET SERVEROUTPUT ON;



--Drop Foreign Keys

ALTER TABLE reviews DROP CONSTRAINT fk_venue_id;
ALTER TABLE reviews DROP CONSTRAINT fk_vp_id;
ALTER TABLE reviews DROP CONSTRAINT fk_reviewer_id;
ALTER TABLE venue_provisions DROP CONSTRAINT fk_vp_venue_id;
ALTER TABLE venue_provisions DROP CONSTRAINT fk_vp_provision_id;



--Drop Primary Keys

ALTER TABLE venue_provisions DROP CONSTRAINT pk_venue_provisions;
ALTER TABLE venues DROP CONSTRAINT pk_venues;
ALTER TABLE reviews DROP CONSTRAINT pk_reviews;
ALTER TABLE reviewers DROP CONSTRAINT pk_reviewers;
ALTER TABLE provisions DROP CONSTRAINT pk_provisions;



--Drop Tables

DROP TABLE reviews;
DROP TABLE reviewers;
DROP TABLE venue_provisions;
DROP TABLE provisions;
DROP TABLE venues;



--Drop Object Tables

Drop TABLE addresses;



--Drop Object Types

DROP TYPE address_type;
DROP TYPE contact_type;

DROP TYPE rating_table_type;
DROP TYPE rating_type;
DROP TYPE grading_varray_type;
DROP TYPE grading_type;



--Drop Sequences

DROP SEQUENCE venue_seq;
DROP SEQUENCE provision_seq;
DROP SEQUENCE reviewer_seq;
DROP SEQUENCE review_seq;



PURGE RECYCLEBIN;



--Create Types

CREATE OR REPLACE TYPE address_type AS OBJECT(
house_number	VARCHAR2(10),
postcode		VARCHAR2(20),
street			VARCHAR2(75),
city			VARCHAR2(25),
country			VARCHAR2(45));
/



CREATE TABLE addresses OF address_type;

CREATE OR REPLACE TYPE contact_type AS OBJECT(
mobile			VARCHAR2(20),
landline		VARCHAR2(25),
country_code		VARCHAR2(8),
email			VARCHAR2(50));
/



CREATE OR REPLACE TYPE grading_type AS OBJECT(
no_of_stars		NUMBER(1),
grading_desc		VARCHAR2(15));
/



CREATE OR REPLACE TYPE grading_varray_type AS VARRAY(5) OF grading_type;
/



CREATE OR REPLACE TYPE rating_type AS OBJECT(
rating_item		VARCHAR2(25),
grading		grading_varray_type);
/



CREATE OR REPLACE TYPE rating_table_type AS TABLE OF rating_type;
/



--Create Tables

CREATE SEQUENCE venue_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE provision_seq START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE reviewer_seq START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE review_seq START WITH 10000 INCREMENT BY 1;



CREATE TABLE venues(
venue_id		NUMBER(6),
venue_name		VARCHAR2(45) NOT NULL,
venue_desc		VARCHAR2(300),
venue_capacity	NUMBER(6),
price			NUMBER(12,2),
venue_category	VARCHAR2(100),
rent_status		CHAR,
venue_address	REF address_type SCOPE IS addresses,
contact_details		contact_type
);



CREATE TABLE provisions (
provision_id 		NUMBER(6),
provision_name 	VARCHAR2(45),
provision_desc 	VARCHAR2(300)
);



CREATE TABLE venue_provisions (
provision_id 		NUMBER(6),
venue_id 		NUMBER(6)
);



CREATE TABLE reviewers(
reviewer_id 		NUMBER(6),
username    		VARCHAR2(50),
password   		VARCHAR(64),
firstname   		VARCHAR2(25),
surname   		 VARCHAR2(25),
reviewer_address 	REF address_type,
contact_details  	contact_type,
date_of_birth  		DATE,
gender    		CHAR DEFAULT 'M'
);



CREATE TABLE reviews(
review_id		NUMBER(6),
review_desc		VARCHAR2(500),
reviewer_id		NUMBER(6),
vp_provision_id	NUMBER(6),
vp_venue_id		NUMBER(6),
venue_id		NUMBER(6),
rating			rating_table_type)
NESTED TABLE rating STORE AS rating_table;



--Primary Keys

ALTER TABLE venues
ADD CONSTRAINT pk_venues PRIMARY KEY(venue_id);



ALTER TABLE provisions
ADD CONSTRAINT pk_provisions PRIMARY KEY(provision_id);



ALTER TABLE venue_provisions
ADD CONSTRAINT pk_venue_provisions PRIMARY KEY(provision_id, venue_id);



ALTER TABLE reviewers
ADD CONSTRAINT pk_reviewers PRIMARY KEY(reviewer_id);



ALTER TABLE reviews
ADD CONSTRAINT pk_reviews PRIMARY KEY(review_id);



--Foreign Keys

ALTER TABLE venue_provisions
ADD CONSTRAINT fk_vp_venue_id 
FOREIGN KEY(venue_id)
REFERENCES venues(venue_id);



ALTER TABLE venue_provisions
ADD CONSTRAINT fk_vp_provision_id
FOREIGN KEY(provision_id)
REFERENCES provisions(provision_id);



ALTER TABLE reviews
ADD CONSTRAINT fk_reviewer_id
FOREIGN KEY(reviewer_id)
REFERENCES reviewers(reviewer_id);



ALTER TABLE reviews
ADD CONSTRAINT fk_vp_id
FOREIGN KEY(vp_provision_id, vp_venue_id)
REFERENCES venue_provisions(provision_id, venue_id);



ALTER TABLE reviews
ADD CONSTRAINT fk_venue_id
FOREIGN KEY(venue_id) 
REFERENCES venues(venue_id);



--Checks

ALTER TABLE reviewers
ADD CONSTRAINT ck_gender CHECK (gender = 'M' OR gender = 'F' OR gender = 'O');



--Functions



--Return a username for a reviewer made up of first name and surname

CREATE OR REPLACE FUNCTION func_create_username(in_firstname reviewers.firstname%TYPE, in_surname reviewers.surname%TYPE)
RETURN VARCHAR2 IS
	vc_reviewer_username VARCHAR2(50);
BEGIN
	vc_reviewer_username := CONCAT(SUBSTR(in_firstname, 1,2), SUBSTR(in_surname,1,3));
	return vc_reviewer_username;

END func_create_username;
/
SHOW ERRORS;



--Return the number of venue reviews

CREATE OR REPLACE FUNCTION func_num_of_venue_reviews(in_venue_id venues.venue_id%TYPE)

RETURN NUMBER IS
	vn_review_num	NUMBER(2);
BEGIN
SELECT COUNT(*)INTO vn_review_num 
FROM reviews
WHERE venue_id = in_venue_id;

RETURN vn_review_num;

END func_num_of_venue_reviews;
/



--Return the number of provision reviews

CREATE OR REPLACE FUNCTION func_num_of_provision_reviews(in_vp_venue_id venue_provisions.venue_id%TYPE)

RETURN NUMBER IS
	vn_prov_review_num NUMBER(2);
BEGIN
	SELECT COUNT(*) INTO vn_prov_review_num
	FROM reviews
	WHERE vp_venue_id = in_vp_venue_id;
	
	RETURN vn_prov_review_num;

END func_num_of_provision_reviews;
/



--Return the total rental cost for a number of days

CREATE OR REPLACE FUNCTION func_num_rental_cost(in_venue_id venues.venue_id%TYPE, in_num_days NUMBER)
RETURN NUMBER IS
	 vn_price NUMBER(4);
 vn_total_cost NUMBER(4);
BEGIN
	SELECT price INTO vn_price FROM venues 
	WHERE venue_id = in_venue_id AND rent_status = 'Y';
	
	IF SQL%ROWCOUNT > 0 THEN
		DBMS_OUTPUT.PUT_LINE('Found venues');
vn_total_cost := vn_price * in_num_days ;
	END IF;

	RETURN vn_total_cost;

END func_num_rental_cost;
/



--Create an average grading/rating for a venue

CREATE OR REPLACE FUNCTION func_average_venue_stars(in_venue_id venues.venue_id%TYPE)
RETURN NUMBER IS	
	vn_avg_stars NUMBER(4) := 0;
	vn_total_stars NUMBER(4) := 0;
	vn_num_ratings NUMBER(4) := 0;
	vc_venue_name venues.venue_name%TYPE;
BEGIN
	
	SELECT venue_name INTO vc_venue_name 
	FROM venues
	WHERE venue_id = in_venue_id;
	
	FOR star_cur IN(SELECT rat.rating_item, gra.no_of_stars
		FROM reviews r, TABLE(r.rating) rat,TABLE(rat.grading) gra
		WHERE r.venue_id = in_venue_id OR r.vp_venue_id = in_venue_id) 

	LOOP
		vn_total_stars := vn_total_stars + star_cur.no_of_stars;
		vn_num_ratings := vn_num_ratings + 1;
	END LOOP;
	
	If vn_num_ratings > 0 THEN
		vn_avg_stars := vn_total_stars / vn_num_ratings;
	END IF;
	RETURN vn_avg_stars;
END func_average_venue_stars;
/



--Procedures/Cursors



--Delete the reviewers cursor

CREATE OR REPLACE PROCEDURE proc_delete_reviewer_cursor(in_id reviewers.reviewer_id%TYPE)IS 
BEGIN
	DELETE FROM reviewers WHERE reviewer_id = in_id;
	IF SQL%FOUND THEN
		DBMS_OUTPUT.PUT_LINE('Reviewer: ' || in_id || ' deleted');
	ELSE
		DBMS_OUTPUT.PUT_LINE('Reviewer: ' || in_id || ' not found in database');
	END IF;
END proc_delete_reviewer_cursor;
/



--Retrieve information from reviews to show the older reviewers

CREATE OR REPLACE PROCEDURE proc_reviewer_older(in_dob reviewers.date_of_birth%TYPE)IS
	CURSOR reviewer_cur IS
	SELECT firstname, surname, date_of_birth 
	FROM reviewers
WHERE date_of_birth > in_dob;
	
	reviewer_rec reviewer_cur%ROWTYPE;
BEGIN
	OPEN reviewer_cur;

	LOOP
		FETCH reviewer_cur INTO reviewer_rec;
		EXIT WHEN reviewer_cur%NOTFOUND;
		
		DBMS_OUTPUT.PUT_LINE(reviewer_rec.firstname || ' ' || reviewer_rec.surname || ' ' || reviewer_rec.date_of_birth);
	END LOOP;

	CLOSE reviewer_cur;
END proc_reviewer_older;
/



--Set the password for a reviewer 

CREATE OR REPLACE PROCEDURE proc_set_password (in_username reviewers.username%type, in_password reviewers.password%type) is
BEGIN
	UPDATE reviewers set password = in_password WHERE username = in_username;	
	IF SQL%ROWCOUNT > 0 THEN	
		DBMS_OUTPUT.PUT_LINE('Password Has Successfully Been Updated');
	ELSE 
		DBMS_OUTPUT.PUT_LINE('No Account Has Been Found. Please Try Again');
	END IF;

END proc_set_password;
/



--Retrieve the number of reviews for venue  

CREATE OR REPLACE PROCEDURE proc_reviews_for_venue(in_venue_id venues.venue_id%TYPE) IS
	vn_venue_review_count NUMBER(2);
	
BEGIN
	vn_venue_review_count := func_num_of_venue_reviews(in_venue_id); 
	DBMS_OUTPUT.PUT_LINE(vn_venue_review_count );
END proc_reviews_for_venue;
/



--Retrieve the rental cost for how many days the user selects in total 

CREATE OR REPLACE PROCEDURE proc_rental_cost(in_venue_id venues.venue_id%TYPE, in_num_days NUMBER)IS

	CURSOR rental_cur IS

SELECT price 
FROM venues
WHERE venue_id = in_venue_id AND rent_status = 'Y';
	
	rental_record rental_cur %ROWTYPE;
BEGIN
	OPEN rental_cur;
	FETCH rental_cur INTO rental_record;
IF rental_cur%FOUND THEN
DBMS_OUTPUT.PUT_LINE(func_num_rental_cost(in_venue_id, in_num_days));
		ELSE
			DBMS_OUTPUT.PUT_LINE('Venue not available for rent');
		END IF;
CLOSE rental_cur;
END proc_rental_cost;
/



--Retrieve reviewers' details by username

CREATE OR REPLACE PROCEDURE proc_reviewer_details(in_username reviewers.username%TYPE)IS
	CURSOR reviewer_cur IS
	SELECT firstname, surname, username, date_of_birth, DEREF(reviewer_address) addr, contact_details, gender
	FROM reviewers
WHERE username = in_username;
	
	reviewer_rec reviewer_cur%ROWTYPE;
BEGIN
	OPEN reviewer_cur;

	LOOP
		FETCH reviewer_cur INTO reviewer_rec;
		EXIT WHEN reviewer_cur%NOTFOUND;
		DBMS_OUTPUT.PUT_LINE('Reviewer Information:');
		DBMS_OUTPUT.PUT_LINE('-----------------------------------------');
		DBMS_OUTPUT.PUT_LINE('First Name - ' || reviewer_rec.firstname);
		DBMS_OUTPUT.PUT_LINE('Surname - ' || reviewer_rec.surname);
		DBMS_OUTPUT.PUT_LINE('Username - ' || reviewer_rec.username);
		DBMS_OUTPUT.PUT_LINE('D.O.B - ' || reviewer_rec.date_of_birth);
		DBMS_OUTPUT.PUT_LINE('Address - ' || reviewer_rec.addr.house_number || ' ' || reviewer_rec.addr.street || ' ' || reviewer_rec.addr.city || ' ' || reviewer_rec.addr.country || ' ' || reviewer_rec.addr.postcode);
		DBMS_OUTPUT.PUT_LINE('Email - ' || reviewer_rec.contact_details.email);
		DBMS_OUTPUT.PUT_LINE('Gender - ' || reviewer_rec.gender);
	
		
	END LOOP; 

	CLOSE reviewer_cur;
END proc_reviewer_details;
/



--Retrieve details of all reviews for a particular venue

CREATE OR REPLACE PROCEDURE proc_review_information(in_venue_id venues.venue_id%TYPE)IS

BEGIN
	DBMS_OUTPUT.PUT_LINE(CHR(10));
	FOR review_con IN (SELECT r.review_desc, r.review_id, re.firstname
FROM reviews r
JOIN reviewers re
ON r.reviewer_id = re.reviewer_id
WHERE r.venue_id = in_venue_id) 
LOOP  
		
		DBMS_OUTPUT.PUT_LINE('Review: ' || review_con.review_desc);
DBMS_OUTPUT.PUT_LINE('Reviewer Name: ' || review_con.firstname);	

FOR review_rec IN (SELECT rat.rating_item, gra.no_of_stars
FROM reviews r, TABLE(r.rating) rat, TABLE(rat.grading) gra
WHERE r.venue_id = in_venue_id AND r.review_id = review_con.review_id) 
LOOP    
DBMS_OUTPUT.PUT_LINE(review_rec.rating_item || ' - ' || review_rec.no_of_stars || '/5');
		
END LOOP;

DBMS_OUTPUT.PUT_LINE(CHR(10));

END LOOP;

END proc_review_information;
/



--Retrieve details of all review provisions for a particular venue

CREATE OR REPLACE PROCEDURE proc_review_prov_info(in_venue_id venues.venue_id%TYPE)IS

BEGIN
	DBMS_OUTPUT.PUT_LINE(CHR(10));
	FOR review_con IN (SELECT r.review_desc, r.review_id, re.firstname, p.provision_name
				FROM reviews r
				JOIN reviewers re
				ON r.reviewer_id = re.reviewer_id
				JOIN venue_provisions vp
				ON r.vp_venue_id = vp.venue_id AND r.vp_provision_id =  vp.provision_id
				JOIN provisions p
				ON vp.provision_id = p.provision_id
				WHERE r.vp_venue_id = in_venue_id)
	LOOP
		DBMS_OUTPUT.PUT_LINE('Provision: ' || review_con.provision_name);
		DBMS_OUTPUT.PUT_LINE('Review: ' || review_con.review_desc);
		DBMS_OUTPUT.PUT_LINE('Reviewer Name: ' || review_con.firstname);
		
		FOR review_rec IN (SELECT rat.rating_item, gra.no_of_stars
					FROM reviews r, TABLE(r.rating) rat,
					TABLE(rat.grading) gra
					WHERE r.vp_venue_id = in_venue_id AND
					r.review_id = review_con.review_id)
		LOOP
			DBMS_OUTPUT.PUT_LINE(review_rec.rating_item || ' - ' ||
			review_rec.no_of_stars || '/5');
		
		END LOOP;
			DBMS_OUTPUT.PUT_LINE(CHR(10));
	END LOOP;
	
END proc_review_prov_info;
/



--Retrieve venues information average star rating

CREATE OR REPLACE PROCEDURE proc_venue_stars(in_venue_id venues.venue_id%TYPE)IS
	
	vn_stars NUMBER(4);

BEGIN
	vn_stars := func_average_venue_stars(in_venue_id);
	DBMS_OUTPUT.PUT_LINE('Average Venue Stars: ' || vn_stars);
	
END proc_venue_stars;
/



--Retrieve venues information above and equal to the entered star rating 

CREATE OR REPLACE PROCEDURE proc_venue_above_star_rating (in_stars NUMBER) is
	vn_stars NUMBER(1);
	
BEGIN	
	FOR venue_cursor IN(SELECT venue_id, venue_name
FROM venues)
	LOOP
		vn_stars := func_average_venue_stars(venue_cursor.venue_id); 
		IF vn_stars >= in_stars THEN
			DBMS_OUTPUT.PUT_LINE(venue_cursor.venue_name || ' ' || vn_stars);
END IF;			
	END LOOP;
	
END proc_venue_above_star_rating;
/



--Retrieve venues information below and equal to the entered star rating 

CREATE OR REPLACE PROCEDURE proc_venue_below_star_rating (in_stars NUMBER) is
	vn_stars NUMBER(1);
	
BEGIN	
	FOR venue_cursor IN(SELECT venue_id, venue_name
FROM venues)
	LOOP
		vn_stars := func_average_venue_stars(venue_cursor.venue_id); 
		IF vn_stars <= in_stars THEN
			DBMS_OUTPUT.PUT_LINE(venue_cursor.venue_name || ' ' || vn_stars);
END IF;			
	END LOOP;
	
END proc_venue_above_star_rating;
/



--Triggers



--Check the reviewer hasn’t entered a date of birth more than system date

CREATE OR REPLACE TRIGGER trig_reviewer_dob_ck
BEFORE INSERT OR UPDATE OF date_of_birth ON reviewers
FOR EACH ROW
WHEN(NEW.date_of_birth > SYSDATE)
BEGIN
	RAISE_APPLICATION_ERROR(-20000, 'ERROR - A reviewer cannot have a date of birth greater than todays date!');
END trig_reviewer_dob_ck;
/



--Give feedback on change of reviewer information such as update, delete etc.

CREATE OR REPLACE TRIGGER trig_reviewer_status
BEFORE INSERT OR UPDATE OR DELETE ON reviewers
FOR EACH ROW
DECLARE
	reviewer_name reviewers.firstname%TYPE;
	reviewer_id reviewers.reviewer_id%TYPE;
reviewer_surname reviewers.surname%TYPE;
	vc_database_user VARCHAR2(25);
BEGIN
	SELECT user INTO vc_database_user
	FROM dual;

	CASE
		WHEN INSERTING THEN
			reviewer_name :=  :NEW.firstname;
			DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------');
			DBMS_OUTPUT.PUT_LINE('Inserting into reviewers: ' || reviewer_name || ' by User: ' || vc_database_user);
			DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------');
		WHEN UPDATING THEN
			reviewer_id :=  :OLD.reviewer_id;
			DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------');
			DBMS_OUTPUT.PUT_LINE('Updating reviewer with ID: ' || reviewer_id || ' by User: ' || vc_database_user );
			DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------');
		WHEN DELETING THEN
			reviewer_name :=  :OLD.firstname;
			reviewer_surname:=  :OLD.surname;
			DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------');
			DBMS_OUTPUT.PUT_LINE('Deleting reviewer: : ' || reviewer_name || ' ' || reviewer_surname || ' by User: ' || vc_database_user);
			DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------');
	END CASE;
END trig_reviewer_status;
/



--Automatically Calculate the grading description (poor, excellent etc) when inserting into a review, e.g if the number of stars is 1 then the grading desc will be ----poor

CREATE OR REPLACE TRIGGER trig_calculate_grad_desc
BEFORE INSERT ON reviews
FOR EACH ROW
DECLARE
BEGIN
FOR i IN :NEW.rating.FIRST .. :NEW.rating.LAST LOOP
		FOR x IN :NEW.rating(i).grading.FIRST .. :NEW.rating(i).grading.LAST LOOP
			IF :NEW.rating(i).grading(x).no_of_stars = 1 THEN
				:NEW.rating(i).grading(x).grading_desc := 'POOR';
			ELSIF :NEW.rating(i).grading(x).no_of_stars = 2 THEN
				:NEW.rating(i).grading(x).grading_desc := 'BELOW AVERAGE';
			ELSIF :NEW.rating(i).grading(x).no_of_stars = 3 THEN
				:NEW.rating(i).grading(x).grading_desc := 'SATISFACTORY';
			ELSIF :NEW.rating(i).grading(x).no_of_stars = 4 THEN
				:NEW.rating(i).grading(x).grading_desc := 'GOOD';
ELSIF :NEW.rating(i).grading(x).no_of_stars = 5 THEN
				:NEW.rating(i).grading(x).grading_desc := 'EXCELLENT';
			END IF;

		END LOOP;
	END LOOP;
END trig_calculate_grad_desc;
/



--Block a review if the reviewer has already reviewed a venue or venue provision

CREATE OR REPLACE TRIGGER trig_block_review
BEFORE INSERT ON reviews
FOR EACH ROW
BEGIN
	FOR review_cur IN(SELECT reviewer_id, venue_id, vp_venue_id FROM reviews) 
LOOP
	IF review_cur.reviewer_id = :NEW.reviewer_id AND review_cur.venue_id = :NEW.venue_id  THEN
		RAISE_APPLICATION_ERROR(-20001, 'Reviewer cannot review the same venue twice');
	ELSIF review_cur.reviewer_id = :NEW.reviewer_id AND review_cur.vp_venue_id = :NEW.vp_venue_id THEN
			RAISE_APPLICATION_ERROR(-20002, 'Reviewer cannot review the same venue provision twice');
		END IF;
	END LOOP;

END trig_block_review;
/



--Number of reviews a reviewer has done on review insert

CREATE OR REPLACE TRIGGER trig_review_count
BEFORE INSERT ON reviews
FOR EACH ROW
DECLARE
	vn_num_reviews NUMBER(4) := 0;
BEGIN
	SELECT COUNT(*) INTO vn_num_reviews 
	FROM reviews
	WHERE reviewer_id = :NEW.reviewer_id;

	vn_num_reviews := vn_num_reviews + 1;

	IF vn_num_reviews = 10 THEN
		DBMS_OUTPUT.PUT_LINE('Congratulations, this is your 10th review!');
	ELSIF vn_num_reviews = 15 THEN
		DBMS_OUTPUT.PUT_LINE('Congratulations, this is your 15th reviews!');
	END IF;
	
END trig_review_count;
/



--Inserts



--Addresses

INSERT INTO addresses VALUES ('55', 'NN1 1DH', 'ST JOHNS STREET', 'NORTHAMPTON', 'ENGLAND');

INSERT INTO addresses VALUES ('25', 'LE4 6PL', 'HOMELAND STREET', 'LEICESTER', 'ENGLAND');

INSERT INTO addresses VALUES ('96', 'TA9 4BU', 'LAPTOP STREET', 'NORWICH', 'ENGLAND');

INSERT INTO addresses VALUES ('118', 'IV26 2XU', 'DESKTOP STREET', 'MANCHESTER', 'ENGLAND');

INSERT INTO addresses VALUES ('72A', 'NN2 4HJ', 'MORTON LANE', 'NORTHAMPTON', 'ENGLAND');

INSERT INTO addresses VALUES ('118', 'GU51 2RS', 'MAC STREET', 'BEDFORD', 'ENGLAND');

INSERT INTO addresses VALUES ('450','FR51 9US', 'HARD DRIVE STREET', 'KETTERING', 'ENGLAND');

INSERT INTO addresses VALUES ('99','GB97 9Q7', 'USB STREET', 'MILTON KEYNES', 'ENGLAND');

INSERT INTO addresses VALUES ('85','LO93 9H7', 'ADAPTOR STREET', 'LIVERPOOL', 'ENGLAND');



--Venues

INSERT INTO venues (venue_id, venue_name, venue_desc, venue_capacity, price, venue_category, rent_status, venue_address, contact_details) 
SELECT
venue_seq.NEXTVAL,
'KETTERING CONFERENCE CENTRE',
'LARGE, MODERN AND VERSATILE VENUE FOR CORPORATE EVENTS AND WEDDINGS WITH A LAKESIDE TERRACE AND BAR.',
300,
100.00,
'CORPORATE, WEDDINGS',
'Y',
REF(a),
contact_type('7865678768','01604414414','+44','KETTERINGCC@GMAIL.com')
FROM addresses a
WHERE a.house_number = '55' AND a.street = 'ST JOHNS STREET';



INSERT INTO venues (venue_id, venue_name, venue_desc, venue_capacity, price, venue_category, rent_status, venue_address, contact_details) 
SELECT
venue_seq.NEXTVAL,
'KAPITAL VENUE',
'KAPITAL VENUES HAS BEEN OPERATING OFFERING ITS SERVICES FOR 9 YEARS.',
1500,
600.00,
'CORPORATE, WEDDINGS, BIRTHDAYS, EVENTS',
'Y',
REF(a),
contact_type('07893455638', '01164873554', '+44','ENQUIRES@KAPITAL.com')
FROM addresses a
WHERE a.house_number = '25' AND a.street = 'HOMELAND STREET';



INSERT INTO venues (venue_id, venue_name, venue_desc, venue_capacity, price, venue_category, rent_status, venue_address, contact_details)
SELECT
venue_seq.NEXTVAL,
'DIAMOND PALACE',
'DIAMOND PALACE IS A WONDERFUL PLACE TO HOST EVENTS',
5000,
985.00,
'MUSICAL EVENTS, WEDDINGS, BIRTHDAYS',
'Y',
REF(a),
contact_type('07834963855', '01603175543', '+44', 'DIAMOND@PALACE.COM')
FROM addresses a 
WHERE a.house_number = '96' AND a.street = 'LAPTOP STREET';



INSERT INTO venues(venue_id, venue_name, venue_desc, venue_capacity, price, venue_category, rent_status, venue_address, contact_details)
SELECT
venue_seq.NEXTVAL,
'HILTON LEICESTER HOTEL',
'PLACE TO MAKE YOUR EVENTS ENJOYABLE AND A DREAM COME TRUE',
1738,
490.00,
'WEDDINGS, BIRTHDAYS, EVENTS',
'Y',
REF(a),
contact_type('07438369558', '01614755134', '+44', 'ENQUIRES@HLH.COM')
FROM addresses a
WHERE a.house_number = '118' AND a.street = 'DESKTOP STREET';



INSERT INTO venues(venue_id, venue_name, venue_desc, venue_capacity, price, venue_category, rent_status, venue_address, contact_details)
SELECT
venue_seq.NEXTVAL,
'NORTHAMPTON MARRIOTT HOTEL',
'THE MARRIOTT HOTEL IS AN EXTREMELY CHARACTERISTIC, QUIET AND LIVELY AREA WITHIN SHORT WALKING DISTANCE TO ALL SITES',
3550,
750.00,
'BIRTHDAYS, EVENTS',
'N',
REF(a),
contact_type('07448399011', '01604755134', '+44', 'maryjane@marriot.COM')
FROM addresses a
WHERE a.house_number = '72A' AND a.street = 'MORTON LANE';



--Reviewers

INSERT INTO reviewers(reviewer_id, username, firstname, surname, reviewer_address, contact_details, date_of_birth, gender)
SELECT reviewer_seq.NEXTVAL, func_create_username('SAM', 'PATTERSON'), 'SAM', 'PATTERSON', REF(a), 
contact_type('07949245594', '01234696969', '+44', 'SAMPATTERSON111994@GMAIL.COM'),
'13-JUN-1994', 'M'
FROM addresses a
WHERE a.house_number = '118' AND a.street = 'MAC STREET';



INSERT INTO reviewers(reviewer_id, username,  firstname, surname, reviewer_address, contact_details, date_of_birth, gender)
SELECT reviewer_seq.NEXTVAL, func_create_username('MACIEK', 'PAWELKIEWICZ'), 'MACIEK', 'PAWELKIEWICZ', REF(a), 
contact_type('07776534251', '01536284927', '+44', 'MACIEJPUNI@GMAIL.COM'),
'07-SEP-1994', 'O'
FROM addresses a
WHERE a.house_number = '450' AND a.street = 'HARD DRIVE STREET';



INSERT INTO reviewers(reviewer_id, username, firstname, surname, reviewer_address, contact_details, date_of_birth, gender)
SELECT reviewer_seq.NEXTVAL, func_create_username('CHARLIE', 'LEEDHAM'), 'CHARLIE', 'LEEDHAM', REF(a), 
contact_type('07339402980', '01908356728', '+44', 'CHARLIELEEDHAM1994@GMAIL.COM'),
'13-JUN-1994', 'M'
FROM addresses a
WHERE a.house_number = '99' AND a.street = 'USB STREET';



INSERT INTO reviewers(reviewer_id, username,  firstname, surname, reviewer_address, contact_details, date_of_birth, gender)
SELECT reviewer_seq.NEXTVAL, func_create_username('MEHUL', 'CHAMUNDA'), 'MEHUL', 'CHAMUNDA', REF(a), 
contact_type('09654833546', '01517632889', '+44', 'M_FAM@OUTLOOK.COM'),
'16-AUG-1996', 'M'
FROM addresses a
WHERE a.house_number = '85' AND a.street = 'ADAPTOR STREET';



INSERT INTO reviewers(reviewer_id, username,  firstname, surname, reviewer_address, contact_details, date_of_birth, gender)
SELECT reviewer_seq.NEXTVAL, func_create_username('JOHN', 'SMITH'), 'JOHN', 'SMITH', REF(a), 
contact_type('09654833546', '01517632889', '+44', 'JSMITH@OUTLOOK.COM'),
'16-AUG-1994', 'M'
FROM addresses a
WHERE a.house_number = '85' AND a.street = 'ADAPTOR STREET';


--Provisions

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'BAR', 'THIS VENUE HAS ACCESS TO A BAR.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'SWIMMING POOL', 'THIS VENUE HAS ACCESS TO A SWIMMING POOL.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'GAMES ROOM', 'THIS VENUE HAS ACCESS TO A GAMES ROOM.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'CAR PARK', 'THIS VENUE HAS ACCESS TO AN ON SITE CAR PARK.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'MAIN HALL', 'THIS VENUE HAS ACCESS TO THE MAIN HALL.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'GARDEN', 'THIS VENUE HAS ACCESS TO A GARDEN.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'CATERING', 'THIS VENUE OFFERS CATERING.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'DISABLED ACCESS', 'THIS VENUE HAS DISABLED ACCESS.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'GYM', 'THIS VENUE HAS ACCESS TO A GYM.');

INSERT INTO provisions VALUES(provision_seq.NEXTVAL, 'LAUNDRETTE', 'THIS VENUE HAS ACCESS TO A ON SITE LAUNDRETTE.');



--Venue Provisions

INSERT INTO venue_provisions VALUES(100,1);
INSERT INTO venue_provisions VALUES(104,1);
INSERT INTO venue_provisions VALUES(106,1);
INSERT INTO venue_provisions VALUES(107,1);


INSERT INTO venue_provisions VALUES(100,2);
INSERT INTO venue_provisions VALUES(103,2);
INSERT INTO venue_provisions VALUES(104,2);
INSERT INTO venue_provisions VALUES(106,2);
INSERT INTO venue_provisions VALUES(107,2);


INSERT INTO venue_provisions VALUES(103,3);
INSERT INTO venue_provisions VALUES(104,3);
INSERT INTO venue_provisions VALUES(107,3);


INSERT INTO venue_provisions VALUES(102,4);
INSERT INTO venue_provisions VALUES(105,4);
INSERT INTO venue_provisions VALUES(106,4);
INSERT INTO venue_provisions VALUES(107,4);


INSERT INTO venue_provisions VALUES(100,5);
INSERT INTO venue_provisions VALUES(102,5);
INSERT INTO venue_provisions VALUES(103,5);
INSERT INTO venue_provisions VALUES(108,5);
INSERT INTO venue_provisions VALUES(109,5);



-- Provisions Reviews

INSERT INTO reviews(review_id, review_desc, reviewer_id, vp_venue_id, vp_provision_id, rating)
VALUES (review_seq.NEXTVAL, 'Very Good drinks', 1000, 1 , 100,
rating_table_type(
rating_type('Customer Service', grading_varray_type(grading_type(5, 'Excellent'))),
rating_type('Waiting Time', grading_varray_type(grading_type(5, 'Excellent')))
));



INSERT INTO reviews(review_id, review_desc, reviewer_id, vp_venue_id, vp_provision_id, rating)
VALUES (review_seq.NEXTVAL,'Very good car park service', 1001, 2 , 103,
rating_table_type(
rating_type('Waiting Time', grading_varray_type(grading_type(5, 'Excellent')))
));



INSERT INTO reviews(review_id, review_desc, reviewer_id, vp_venue_id, vp_provision_id, rating)
VALUES (review_seq.NEXTVAL,'Nice warm water',1002,3,103,
rating_table_type(
rating_type('Waiting Time', grading_varray_type(grading_type(5, 'Excellent'))),
rating_type('Cleanliness', grading_varray_type(grading_type(5, 'Excellent')))
));



INSERT INTO reviews(review_id, review_desc, reviewer_id, vp_venue_id, vp_provision_id, rating)
VALUES (review_seq.NEXTVAL,'Very good hall', 1003, 4 , 105,
rating_table_type(
rating_type('Sound Quality', grading_varray_type(grading_type(4, 'Good'))),
rating_type('TV Screens', grading_varray_type(grading_type(4, 'Excellent')))
));



-- Venue Reviews

INSERT INTO reviews (review_id, review_desc, reviewer_id, venue_id, rating)
VALUES(review_seq.NEXTVAL,'What a nice place :D', 1000,2,
rating_table_type(
rating_type('Cleanliness', grading_varray_type(grading_type(1,'Poor'))),
rating_type('Customer Service', grading_varray_type(grading_type(3,'Satisfactory'))),
rating_type('Waiting Time', grading_varray_type(grading_type(2,'Below Average')))
));



INSERT INTO reviews (review_id, review_desc, reviewer_id, venue_id, rating)
VALUES(review_seq.NEXTVAL,'Not a good experience, will not be returning in the future.', 1001,1,
rating_table_type(
rating_type('Cleanliness', grading_varray_type(grading_type(1,'Poor'))),
rating_type('Customer Service', grading_varray_type(grading_type(3,'Satisfactory'))),
rating_type('Waiting Time', grading_varray_type(grading_type(2,'Below Average')))
));



--Queries



COLUMN review_desc FORMAT A60;
COLUMN venue_name FORMAT A30;
COLUMN username FORMAT A10;


--Show all reviewers and their reviews if they have any

SELECT re.username,  r.review_desc, v.venue_name, p.provision_name venue_provision
FROM reviewers re
LEFT JOIN reviews r
ON re.reviewer_id = r.reviewer_id
LEFT JOIN venues v
ON r.venue_id = v.venue_id
LEFT JOIN venue_provisions vp
ON r.vp_provision_id = vp.provision_id AND r.vp_venue_id = vp.venue_id
LEFT JOIN provisions p
ON vp.provision_id = p.provision_id;



--Show venue with the lowest price

SELECT venue_name, MIN(price)
FROM venues
WHERE rownum = 1
GROUP BY (venue_name)
ORDER BY MIN(price);



--Show venue with the highest price

SELECT * FROM(
SELECT venue_name, MAX(price) 
FROM venues
GROUP BY (venue_name)
ORDER BY MAX(price) DESC)
WHERE rownum = 1;



--Round venue prices to nearest 10

SELECT ROUND(price, - 1) , price
FROM venues;



--Show only reviewers which have made a review

SELECT reviewer_id
FROM reviewers
INTERSECT
SELECT reviewer_id
FROM reviews;



--Show all reviewer's addresses

COLUMN firstname FORMAT A15;
COLUMN surname FORMAT A15;
COLUMN Number FORMAT A10;
COLUMN Street FORMAT A25;
COLUMN City FORMAT A15;
COLUMN Country FORMAT A15;
COLUMN Postcode FORMAT A15;

SELECT r.firstname, r.surname, r.reviewer_address.house_number "Number", r.reviewer_address.street "Street",
r.reviewer_address.city "City", r.reviewer_address.country "Country", r.reviewer_address.postcode "Postcode"
FROM reviewers r;



--Show all venue's contact details

COLUMN Venue FORMAT A30;
COLUMN Country Code FORMAT A8;
COLUMN Mob FORMAT A13;
COLUMN Landline FORMAT A15;
COLUMN Email FORMAT A30;

SELECT v.venue_name "Venue", v.contact_details.country_code "Country Code", v.contact_details.mobile "Mob", v.contact_details.landline "Landline", v.contact_details.email "Email"
FROM venues v;



--Shows all venue ids for venues which have not been reviewed

SELECT venue_id
FROM venues
MINUS
SELECT venue_id
FROM reviews;



--Show venues which have reviews and their price is greater than 500

SELECT venue_id 
FROM venues
WHERE price > 500
UNION
SELECT venue_id	
FROM reviews;



--Show the average price of venues with an average star rating greater than 3

SELECT  AVG(price)
FROM venues
WHERE func_average_venue_stars(venue_id) > 3
ORDER BY AVG(price);



--Show the number of provision reviews for each venue

SELECT COUNT(*) "No. Of Provision Reviews", v.venue_name
FROM reviews r
JOIN venue_provisions vp
ON r.vp_venue_id = vp.venue_id AND r.vp_provision_id = vp.provision_id
JOIN venues v
ON v.venue_id = vp.venue_id
GROUP BY v.venue_name
ORDER BY COUNT(*);



--Show sum of all venue stars, inlcuding venue reviews and venue provision reviews

SELECT  v.venue_name, (SELECT SUM(gra.no_of_stars)
			FROM reviews r, TABLE(r.rating) rat, TABLE(rat.grading) gra
WHERE r.venue_id = v.venue_id OR r.vp_venue_id = v.venue_id) AS "Total Stars"
FROM venues v;
