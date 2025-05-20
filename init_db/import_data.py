import os
import glob
import psycopg2

# Подгружаем переменные окружения (например, из docker-compose)
PGDATABASE = os.getenv('POSTGRES_DB')
PGUSER = os.getenv('POSTGRES_USER')
PGPASSWORD = os.getenv('POSTGRES_PASSWORD')
PGHOST = os.getenv('POSTGRES_HOST', 'localhost')  # можно указать "db" если внутри docker-compose
PGPORT = os.getenv('POSTGRES_PORT', '5432')
PGDATABASE = 'bigdata'
PGUSER = 'user'
PGPASSWORD = 'password'
# Путь к CSV-файлам
DATA_DIR = '/data'
CSV_FILES = glob.glob(os.path.join(DATA_DIR, 'MOCK_DATA*.csv'))

# Подключение к БД
try:
    conn = psycopg2.connect(
        dbname='bigdata',
        user='user',
        password='password',
        host=PGHOST,
        port=5432
    )
    conn.autocommit = True
    crsr = conn.cursor()
    print('БД подключено')
    for filepath in CSV_FILES:
        print(f"Обработка файла: {filepath}")
        with open(filepath, 'r', encoding='utf-8') as f:
            # Используем COPY ... FROM STDIN
            crsr.copy_expert(
                sql=f"""
                    COPY mock_data_raw FROM STDIN
                    WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',')
                """,
                file=f
            )

    print("Импорт завершён.")

    # Закрываем соединение
    crsr.close()
    conn.close()
except:
    print('Ошибка с подключение к БД')

