CREATE OR REPLACE PACKAGE UTIL IS
    
    gc_min_salary CONSTANT NUMBER := 2000;
    gc_percent_of_min_salary CONSTANT NUMBER := 1.5;
    
    FUNCTION get_job_title (p_employee_id IN NUMBER) RETURN VARCHAR;
    
    FUNCTION get_dep_name (p_employee_id IN employees.employee_id%TYPE) RETURN VARCHAR2;

    FUNCTION add_years(p_date IN DATE DEFAULT SYSDATE,
                       p_year IN NUMBER ) RETURN DATE;
                       
    PROCEDURE DEL_JOBS (P_JOB_ID IN JOBS.JOB_ID%TYPE, PO_RESULT OUT VARCHAR2);   
    
    PROCEDURE add_new_jobs(p_job_id     IN VARCHAR2, 
                           p_job_title  IN VARCHAR2, 
                           p_min_salary IN NUMBER, 
                           p_max_salary IN NUMBER DEFAULT NULL,
                           po_err       OUT VARCHAR2);
                           
    TYPE rec_region_emp IS RECORD (region_name     VARCHAR2(50),
                                   employee_count  NUMBER);

    TYPE tab_region_emp IS TABLE OF rec_region_emp;

    FUNCTION get_region_cnt_emp(p_department_id NUMBER DEFAULT NULL) 
    RETURN tab_region_emp PIPELINED;
    
    PROCEDURE add_employee(p_first_name      IN VARCHAR2,
                           p_last_name       IN VARCHAR2,
                           p_email           IN VARCHAR2,
                           p_phone_number    IN VARCHAR2,
                           p_hire_date       IN DATE DEFAULT trunc(sysdate, 'dd'),
                           p_job_id          IN VARCHAR2,
                           p_salary          IN NUMBER,
                           p_commission_pct  IN VARCHAR2 DEFAULT NULL,
                           p_manager_id      IN NUMBER DEFAULT 100,
                           p_department_id   IN NUMBER);

    PROCEDURE fire_an_employee(p_employee_id IN NUMBER); 

    PROCEDURE change_attribute_employee(p_employee_id   IN VARCHAR2,
                                        p_first_name    IN VARCHAR2 DEFAULT NULL,
                                        p_last_name     IN VARCHAR2 DEFAULT NULL,
                                        p_email         IN VARCHAR2 DEFAULT NULL,
                                        p_phone_number  IN VARCHAR2 DEFAULT NULL,
                                        p_job_id        IN VARCHAR2 DEFAULT NULL,
                                        p_salary        IN NUMBER   DEFAULT NULL,
                                        p_commission_pct IN VARCHAR2 DEFAULT NULL,
                                        p_manager_id    IN NUMBER   DEFAULT NULL,
                                        p_department_id IN NUMBER   DEFAULT NULL);

END util;
