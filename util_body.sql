create or replace PACKAGE BODY UTIL IS

FUNCTION get_job_title(p_employee_id IN NUMBER) RETURN VARCHAR IS
    v_job_title jobs.job_title%TYPE;
BEGIN
    SELECT j.job_title
    INTO v_job_title
    FROM employees em
    JOIN jobs j ON em.job_id = j.job_id
    WHERE em.employee_id = p_employee_id;

    RETURN v_job_title;
    
END get_job_title;


FUNCTION get_dep_name (p_employee_id IN EMPLOYEES.EMPLOYEE_ID%TYPE) RETURN VARCHAR2 IS
    v_department_name VARCHAR2(100);
BEGIN
    SELECT dep.department_name
    INTO v_department_name
    FROM departments dep
    JOIN employees em ON dep.department_id = em.department_id
    WHERE em.employee_id = p_employee_id;

    RETURN v_department_name;
        
END get_dep_name;


PROCEDURE DEL_JOBS (P_JOB_ID   IN JOBS.JOB_ID%TYPE,
                    PO_RESULT  OUT VARCHAR2) IS
    v_job_count NUMBER;
BEGIN
    -- Перевірка існування посади
    SELECT COUNT(*)
    INTO v_job_count
    FROM JOBS
    WHERE JOB_ID = P_JOB_ID;

    IF v_job_count = 0 THEN
        PO_RESULT := 'Посада ' || P_JOB_ID || ' не існує';
        RETURN;
    ELSE
        DELETE FROM JOBS WHERE JOB_ID = P_JOB_ID;
        PO_RESULT := 'Посада ' || P_JOB_ID || ' успішно видалена';
    END IF;
    
END DEL_JOBS;


FUNCTION add_years(p_date IN DATE,
                   p_year IN NUMBER) RETURN DATE IS
     v_date DATE;
     v_year NUMBER := p_year*12;
BEGIN
     SELECT add_months(p_date, v_year)
     INTO v_date
     FROM dual;
     RETURN v_date;

END add_years;


PROCEDURE add_new_jobs(p_job_id      IN VARCHAR2,
                       p_job_title   IN VARCHAR2,
                       p_min_salary  IN NUMBER,
                       p_max_salary  IN NUMBER DEFAULT NULL,
                       po_err        OUT VARCHAR2) IS
                                         
c_percent_of_min_salary CONSTANT NUMBER := 1.5;
gc_min_salary CONSTANT NUMBER := 2000;
v_max_salary jobs.max_salarY%TYPE;  
salary_err EXCEPTION;
                       
 BEGIN
       IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN') THEN
          raise_application_error (-20205, 'Ви можете вносити зміни лише у робочі дні');
       END IF;
       
       IF p_max_salary IS NULL THEN
          v_max_salary := p_min_salary * c_percent_of_min_salary;
       ELSE
          v_max_salary := p_max_salary;
       END IF;
       
 BEGIN
       IF (p_min_salary < gc_min_salary OR p_max_salary < gc_min_salary) THEN
           RAISE salary_err;
       ELSE
           INSERT INTO kristina.jobs(job_id, job_title, min_salary, max_salary)
           VALUES (p_job_id, p_job_title, p_min_salary, v_max_salary);
           COMMIT;
           po_err := 'Посада '||p_job_id||' успішно додана';
       END IF;    
           
 EXCEPTION
       WHEN salary_err THEN
       raise_application_error(-20001, 'Передана зарплата менша за 2000');
       WHEN dup_val_on_index THEN
       raise_application_error(-20002, 'Посада '||p_job_id||' вже існує');
       WHEN OTHERS THEN
       raise_application_error(-20003, 'Виникла помилка при додаванні нової посади. '|| SQLERRM);
       END;

END add_new_jobs;

FUNCTION get_region_cnt_emp(p_department_id NUMBER DEFAULT NULL) 
RETURN tab_region_emp PIPELINED IS
       v_record rec_region_emp;
CURSOR cur IS
SELECT 
    r.region_name, 
    COUNT(e.employee_id) AS emp_count
FROM 
    HR.regions r
JOIN 
    HR.countries c ON r.region_id = c.region_id
JOIN 
    HR.locations l ON c.country_id = l.country_id
JOIN 
    HR.departments dep ON l.location_id = dep.location_id
JOIN 
    HR.employees e ON dep.department_id = e.department_id
WHERE 
    e.department_id = null OR null IS null
GROUP BY 
    r.region_name;
    BEGIN
        OPEN cur;
        LOOP
            FETCH cur INTO v_record;
            EXIT WHEN cur%NOTFOUND;
            PIPE ROW(v_record);
        END LOOP;
        CLOSE cur;
        RETURN;

    END get_region_cnt_emp;
    

PROCEDURE add_employee(
        p_first_name      IN VARCHAR2,
        p_last_name       IN VARCHAR2,
        p_email           IN VARCHAR2,
        p_phone_number    IN VARCHAR2,
        p_hire_date       IN DATE DEFAULT trunc(sysdate, 'dd'),
        p_job_id          IN VARCHAR2,
        p_salary          IN NUMBER,
        p_commission_pct  IN VARCHAR2 DEFAULT NULL,
        p_manager_id      IN NUMBER DEFAULT 100,
        p_department_id   IN NUMBER
    ) IS
        v_employee_id     NUMBER;
        v_min_salary      NUMBER;
        v_max_salary      NUMBER;
        v_day_of_week     NUMBER;
        v_current_time    VARCHAR2(5);

    BEGIN
        -- Викликати процедуру log_util.log_start
        log_util.log_start(p_proc_name => 'add_employee');

        -- Перевірити, чи існує переданий код посади (P_JOB_ID) в таблиці JOBS
        BEGIN
            SELECT min_salary, max_salary INTO v_min_salary, v_max_salary
            FROM jobs
            WHERE job_id = p_job_id;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Введено неіснуючий код посади');
        END;

        -- Перевірити, чи існує переданий ідентифікатор відділу (P_DEPARTMENT_ID) в таблиці DEPARTMENTS
        BEGIN
            SELECT 1 INTO v_employee_id
            FROM departments
            WHERE department_id = p_department_id;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Введено неіснуючий ідентифікатор відділу');
        END;

        -- Перевірити передану заробітну плату на коректність за кодом посади (P_JOB_ID)
        IF p_salary < v_min_salary OR p_salary > v_max_salary THEN
            RAISE_APPLICATION_ERROR(-20001, 'Введено неприпустиму заробітну плату для даного коду посади');
        END IF;

        -- Перевірити день і час при вставці
        v_day_of_week := to_number(to_char(p_hire_date, 'D'));
        v_current_time := to_char(sysdate, 'HH24:MI');

        IF v_day_of_week IN (7, 1) OR (v_current_time < '08:00' OR v_current_time > '18:00') THEN
            RAISE_APPLICATION_ERROR(-20001, 'Ви можете додавати нового співробітника лише в робочий час');
        END IF;

        -- Вставка нового співробітника
        BEGIN
            SELECT MAX(employee_id) + 1 INTO v_employee_id FROM employees;

            INSERT INTO employees (
                employee_id, first_name, last_name, email, phone_number, hire_date,
                job_id, salary, commission_pct, manager_id, department_id
            ) VALUES (
                v_employee_id, p_first_name, p_last_name, p_email, p_phone_number, p_hire_date,
                p_job_id, p_salary, p_commission_pct, p_manager_id, p_department_id
            );

            DBMS_OUTPUT.PUT_LINE('Співробітник ' || p_first_name || ', ' || p_last_name || ', ' || p_job_id || ', ' || p_department_id || ' успішно додано до системи');
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Викликати процедуру log_util.log_error у випадку помилки
                log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => SQLERRM);
                RAISE;  -- Перепідняти виняток для передачі повідомлення про помилку
        END;

        -- Викликати процедуру log_util.log_finish
        log_util.log_finish(p_proc_name => 'add_employee');

    END add_employee;


-- Процедура для перевірки робочого часу
    PROCEDURE check_working_hours IS
    BEGIN
        IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = ''ENGLISH''') IN ('SAT', 'SUN') OR
           TO_CHAR(SYSDATE, 'HH24MI') NOT BETWEEN '0800' AND '1800' THEN
            RAISE_APPLICATION_ERROR(-20001, 'Ви можете видалити співробітника тільки в робочий час');
        END IF;
    END check_working_hours;


    PROCEDURE fire_an_employee(p_employee_id IN NUMBER) IS
        v_first_name   VARCHAR2(50);
        v_last_name    VARCHAR2(50);
        v_job_id       VARCHAR2(10);
        v_department_id NUMBER;
        
    BEGIN
        -- Лог початку
        log_util.log_start('fire_an_employee');

        -- Перевірка, чи існує співробітник з переданим ідентифікатором
        BEGIN
            SELECT first_name, last_name, job_id, department_id
            INTO v_first_name, v_last_name, v_job_id, v_department_id
            FROM employees
            WHERE employee_id = p_employee_id;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Переданий співробітник не існує');
        END;

        -- Перевірка робочого часу
        check_working_hours;

        -- Видалення співробітника 
        BEGIN
            DELETE FROM employees
            WHERE employee_id = p_employee_id;

            -- Запис в історичну таблицю звільнених співробітників
            INSERT INTO employees_history (
                employee_id, first_name, last_name, job_id, department_id, fired_date
            ) VALUES (
                p_employee_id, v_first_name, v_last_name, v_job_id, v_department_id, SYSDATE
            );

            -- Повідомлення про успішне звільнення
            DBMS_OUTPUT.PUT_LINE('Співробітник ' || v_first_name || ', ' || v_last_name ||
                                 ', ' || v_job_id || ', ' || v_department_id || ' успішно звільнен.');
        EXCEPTION
            WHEN OTHERS THEN
                log_util.log_error('fire_an_employee', SQLERRM);
                RAISE;
        END;

        -- Лог завершення
        log_util.log_finish('fire_an_employee');
        
    END fire_an_employee;
  
  
  PROCEDURE change_attribute_employee (
        p_employee_id        IN VARCHAR2,
        p_first_name         IN VARCHAR2 DEFAULT NULL,
        p_last_name          IN VARCHAR2 DEFAULT NULL,
        p_email              IN VARCHAR2 DEFAULT NULL,
        p_phone_number       IN VARCHAR2 DEFAULT NULL,
        p_job_id             IN VARCHAR2 DEFAULT NULL,
        p_salary             IN NUMBER DEFAULT NULL,
        p_commission_pct     IN VARCHAR2 DEFAULT NULL,
        p_manager_id         IN NUMBER DEFAULT NULL,
        p_department_id      IN NUMBER DEFAULT NULL
    ) IS
  
  BEGIN
    log_util.log_start('change_attribute_employee');

    IF p_first_name IS NULL AND p_last_name IS NULL AND p_email IS NULL AND 
       p_phone_number IS NULL AND p_job_id IS NULL AND p_salary IS NULL AND 
       p_commission_pct IS NULL AND p_manager_id IS NULL AND p_department_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Не вказано жоден параметр для оновлення.');
    END IF;


    IF p_first_name IS NOT NULL THEN
        UPDATE employees
        SET first_name = p_first_name
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_last_name IS NOT NULL THEN
        UPDATE employees
        SET last_name = p_last_name
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_email IS NOT NULL THEN
        UPDATE employees
        SET email = p_email
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_phone_number IS NOT NULL THEN
        UPDATE employees
        SET phone_number = p_phone_number
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_job_id IS NOT NULL THEN
        UPDATE employees
        SET job_id = p_job_id
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_salary IS NOT NULL THEN
        UPDATE employees
        SET salary = p_salary
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_commission_pct IS NOT NULL THEN
        UPDATE employees
        SET commission_pct = p_commission_pct
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_manager_id IS NOT NULL THEN
        UPDATE employees
        SET manager_id = p_manager_id
        WHERE employee_id = p_employee_id;
    END IF;

    IF p_department_id IS NOT NULL THEN
        UPDATE employees
        SET department_id = p_department_id
        WHERE employee_id = p_employee_id;
    END IF;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Немає оновлених записів для співробітника з employee_id = ' || p_employee_id);
    END IF;

    DBMS_OUTPUT.PUT_LINE('У співробітника ' || p_employee_id || ' успішно оновлені атрибути.');

    log_util.log_finish('change_attribute_employee');

EXCEPTION
    WHEN OTHERS THEN
        log_util.log_error('change_attribute_employee', SQLERRM);
        RAISE;
        
    END change_attribute_employee;
    
 
FUNCTION table_from_list(p_list_val IN VARCHAR2,
                         p_separator IN VARCHAR2 DEFAULT ',') 
RETURN tab_value_list PIPELINED IS
    l_start     NUMBER := 1;
    l_end       NUMBER;
    l_value     VARCHAR2(100);
    
BEGIN
    -- Loop through the list
    LOOP
        l_end := INSTR(p_list_val, p_separator, l_start);
        IF l_end = 0 THEN
            l_value := SUBSTR(p_list_val, l_start);
            IF l_value IS NOT NULL THEN
                PIPE ROW(rec_value_list(l_value));
            END IF;
            EXIT;
        ELSE
            l_value := SUBSTR(p_list_val, l_start, l_end - l_start);
            IF l_value IS NOT NULL THEN
                PIPE ROW(rec_value_list(l_value));
            END IF;
            l_start := l_end + LENGTH(p_separator);
        END IF;
    END LOOP;

    RETURN;
    
END table_from_list;


FUNCTION get_currency(
    p_currency     IN VARCHAR2 DEFAULT 'USD',
    p_exchangedate IN DATE DEFAULT SYSDATE
) RETURN tab_exchange PIPELINED IS

BEGIN
    FOR rec IN (
        SELECT r030, txt, rate, cur, TO_DATE(exchangedate, 'dd.mm.yyyy') AS exchangedate
        FROM (
            SELECT get_needed_curr(p_valcode => p_currency, p_date => p_exchangedate) AS json_value
            FROM dual
        ),
        json_table(
            json_value, '$[*]'
            COLUMNS (
                r030           NUMBER        PATH '$.r030',
                txt            VARCHAR2(100) PATH '$.txt',
                rate           NUMBER        PATH '$.rate',
                cur            VARCHAR2(100) PATH '$.cc',
                exchangedate   VARCHAR2(100) PATH '$.exchangedate'
            )
        ) TT
    ) LOOP
        PIPE ROW(rec);
    END LOOP;
    
END get_currency;
    
 
 PROCEDURE copy_table(p_source_scheme IN VARCHAR2,
                      p_target_scheme IN VARCHAR2 DEFAULT USER,
                      p_list_table    IN VARCHAR2,
                      p_copy_data     IN BOOLEAN DEFAULT FALSE,
                      po_result       OUT VARCHAR) 
 AS
    CURSOR c_tables IS
        SELECT table_name, 
               'CREATE TABLE ' || p_target_scheme || '.' || table_name || ' (' ||
               LISTAGG(column_name || ' ' || data_type || count_symbol, ', ') WITHIN GROUP (ORDER BY column_id) || ')' AS ddl_code
        FROM (
            SELECT table_name,
                   column_name,
                   data_type,
                   CASE
                       WHEN data_type = 'VARCHAR2' THEN '(' || data_length || ')'
                       WHEN data_type = 'DATE' THEN NULL
                       WHEN data_type = 'NUMBER' THEN REPLACE('(' || data_precision || ',' || data_scale || ')', '(,)', NULL)
                   END AS count_symbol,
                   column_id
            FROM all_tab_columns
            WHERE owner = UPPER(p_source_scheme)
              AND table_name IN (SELECT * FROM TABLE(table_from_list(p_list_table)))
            ORDER BY table_name, column_id
        )
        GROUP BY table_name;
    
    v_ddl_code  VARCHAR2(4000);  -- Для збереження згенерованого DDL
    v_sql       VARCHAR2(4000);  -- Для динамічних запитів
    
BEGIN
    to_log('COPY_TABLE', 'Старт копіювання таблиць з схеми ' || p_source_scheme || ' в схему ' || p_target_scheme);

    FOR r_table IN c_tables LOOP
        BEGIN
            v_ddl_code := r_table.ddl_code;

            EXECUTE IMMEDIATE v_ddl_code;

            to_log('COPY_TABLE', 'Таблиця ' || r_table.table_name || ' успішно створена.');

            IF p_copy_data THEN
                -- Копіювання даних, якщо вказано p_copy_data = TRUE
                v_sql := 'INSERT INTO ' || p_target_scheme || '.' || r_table.table_name || 
                         ' SELECT * FROM ' || p_source_scheme || '.' || r_table.table_name;
                
                EXECUTE IMMEDIATE v_sql;
                
                to_log('COPY_TABLE', 'Дані успішно скопійовані для таблиці ' || r_table.table_name || '.');
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                to_log('COPY_TABLE', 'Помилка при створенні таблиці ' || r_table.table_name || ': ' || SQLERRM);
                CONTINUE; 
        END;
    END LOOP;

    to_log('COPY_TABLE', 'Копіювання таблиць завершено.');
    po_result := 'Копіювання завершено успішно.';
        
END copy_table;  


PROCEDURE api_nbu_sync IS
    v_list_currencies VARCHAR2(2000);
BEGIN
    BEGIN

        SELECT value_text INTO v_list_currencies
        FROM sys_params
        WHERE param_name = 'list_currencies';

        -- Цикл по валютам
        FOR rec IN (SELECT value_list AS curr FROM TABLE(util.table_from_list(v_list_currencies))) LOOP

            INSERT INTO cur_exchange (R030, TXT, RATE, CUR, EXCHANGEDATE, CHANGE_DATE)
            SELECT r030, txt, rate, cur, exchangedate, SYSDATE
            FROM TABLE(util.get_currency(p_currency => rec.curr));


            log_util.log_finish(p_proc_name => 'api_nbu_sync', p_text => 'Currency ' || rec.curr || ' successfully updated.');
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN

            log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => SQLERRM);
            RAISE_APPLICATION_ERROR(-20001, 'Error during currency update: ' || SQLERRM);
    END;
    
END api_nbu_sync;

     
END util;

