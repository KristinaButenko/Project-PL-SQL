CREATE OR REPLACE PACKAGE log_util AS
    PROCEDURE log_start(p_proc_name IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL);
    PROCEDURE log_finish(p_proc_name IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL);
    PROCEDURE log_error(p_proc_name IN VARCHAR2, p_sqlerrm IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL);
END log_util;


CREATE OR REPLACE PACKAGE BODY log_util AS

    PROCEDURE to_log(p_appl_proc IN VARCHAR2, p_message IN VARCHAR2) IS
    BEGIN
        -- Запис до журналу
        DBMS_OUTPUT.PUT_LINE('Процес: ' || p_appl_proc || ' Повідомлення: ' || p_message);
    END to_log;

    -- Процедура log_start
    PROCEDURE log_start(p_proc_name IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL) IS
        v_text VARCHAR2(4000);
    BEGIN
        IF p_text IS NULL THEN
            v_text := 'Старт логування, назва процесу = ' || p_proc_name;
        ELSE
            v_text := p_text;
        END IF;

        to_log(p_appl_proc => p_proc_name, p_message => v_text);
    END log_start;

    -- Процедура log_finish
    PROCEDURE log_finish(p_proc_name IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL) IS
        v_text VARCHAR2(4000);
    BEGIN
        IF p_text IS NULL THEN
            v_text := 'Завершення логування, назва процесу = ' || p_proc_name;
        ELSE
            v_text := p_text;
        END IF;

        to_log(p_appl_proc => p_proc_name, p_message => v_text);
    END log_finish;

    -- Процедура log_error
    PROCEDURE log_error(p_proc_name IN VARCHAR2, p_sqlerrm IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL) IS
        v_text VARCHAR2(4000);
    BEGIN
        IF p_text IS NULL THEN
            v_text := 'В процедурі ' || p_proc_name || ' сталася помилка. ' || p_sqlerrm;
        ELSE
            v_text := p_text;
        END IF;

        to_log(p_appl_proc => p_proc_name, p_message => v_text);
    END log_error;

END log_util;


-- Тестування:
BEGIN
    -- Тестування процедури log_start
    log_util.log_start(p_proc_name => 'Процес_1');
    log_util.log_start(p_proc_name => 'Процес_1', p_text => 'Початок спеціального логування');

    -- Тестування процедури log_finish
    log_util.log_finish(p_proc_name => 'Процес_1');
    log_util.log_finish(p_proc_name => 'Процес_1', p_text => 'Спеціальне завершення логування');

    -- Тестування процедури log_error
    log_util.log_error(p_proc_name => 'Процес_1', p_sqlerrm => 'Помилка доступу до бази даних');
    log_util.log_error(p_proc_name => 'Процес_1', p_sqlerrm => 'Помилка доступу до бази даних', p_text => 'Спеціальне повідомлення про помилку');
END;
/
