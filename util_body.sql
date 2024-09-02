CREATE OR REPLACE PACKAGE BODY UTIL IS

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

  
END util;
