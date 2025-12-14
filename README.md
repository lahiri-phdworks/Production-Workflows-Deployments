# Apache Airflow demo project

This folder holds a tiny Apache Airflow project with a single DAG that chains three
Python tasks (extract, transform, load). Follow the steps below if you are new to
Airflow and want to try the workflow locally.

- [https://github.com/apache/airflow](https://github.com/apache/airflow)
- [https://github.com/apache/airflow?tab=readme-ov-file#principles](https://github.com/apache/airflow?tab=readme-ov-file#principles)
- [https://airflow.apache.org/](https://airflow.apache.org/)
- [https://www.datacamp.com/tutorial/getting-started-with-apache-airflow](https://www.datacamp.com/tutorial/getting-started-with-apache-airflow)

## Astronomer.

Apart for coldplay tickets, there are a quite a few things to learn and investigate here.

- [https://www.astronomer.io/docs/home/astronomer-documentation](https://www.astronomer.io/docs/home/astronomer-documentation)
- [https://www.astronomer.io/](https://www.astronomer.io/)

## Examples 

- [https://www.datacamp.com/tutorial/building-an-etl-pipeline-with-airflow](https://www.datacamp.com/tutorial/building-an-etl-pipeline-with-airflow)
- [https://www.datacamp.com/tutorial/getting-started-with-apache-airflow](https://www.datacamp.com/tutorial/getting-started-with-apache-airflow)
- [https://www.datacamp.com/blog/what-is-a-dag](https://www.datacamp.com/blog/what-is-a-dag)
- [https://www.datacamp.com/blog/data-contracts](https://www.datacamp.com/blog/data-contracts)

## 1. Install prerequisites

* Python 3.11+
* [uv](https://github.com/astral-sh/uv) (`pip install uv` or use a package manager)
* (optional) Docker, if you prefer to run Airflow inside a container

```bash
cd Airflow
# Not ncessary with uv
uv venv .venv
source .venv/bin/activate

export AIRFLOW_HOME="$(pwd)/airflow_home"
export AIRFLOW__CORE__DAGS_FOLDER="$(pwd)/dags"  # point Airflow at the repo DAGs

AIRFLOW_VERSION=3.1.5
PYTHON_VERSION="$(python -V | awk '{print $2}' | cut -d'.' -f1-2)"

CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
uv pip install --constraint "${CONSTRAINT_URL}" "apache-airflow==${AIRFLOW_VERSION}"
uv add --constraints "${CONSTRAINT_URL}" "apache-airflow==${AIRFLOW_VERSION}"

uv run airflow standalone
```

Manadatory to note the user name and the password, printed in the terminal at the start of the application.

### Some valid constraint file links. 

- [https://raw.githubusercontent.com/apache/airflow/constraints-3.1.5/constraints-3.10.txt](https://raw.githubusercontent.com/apache/airflow/constraints-3.1.5/constraints-3.10.txt)
- [https://raw.githubusercontent.com/apache/airflow/constraints-3.1.5/constraints-3.13.txt](https://raw.githubusercontent.com/apache/airflow/constraints-3.1.5/constraints-3.13.txt)


> You only have to export `AIRFLOW_HOME` once per shell. Keeping it inside the
> project makes cleanup easy.

## 2. Initialize Airflow

```bash
mkdir -p "${AIRFLOW_HOME}"
airflow db init
airflow users create \
  --username admin \
  --firstname Demo \
  --lastname User \
  --role Admin \
  --email demo@example.com \
  --password airflow
```

Set `AIRFLOW__CORE__LOAD_EXAMPLES=False` if you do not want the stock example DAGs:

```bash
export AIRFLOW__CORE__LOAD_EXAMPLES=False
```

## 3. Start the webserver and scheduler

Use separate terminals (both with the virtual environment activated):

```bash
# Terminal 1
cd Airflow
source .venv/bin/activate
export AIRFLOW_HOME="$(pwd)/airflow_home"
export AIRFLOW__CORE__DAGS_FOLDER="$(pwd)/dags"
airflow webserver

# Terminal 2
cd Airflow
source .venv/bin/activate
export AIRFLOW_HOME="$(pwd)/airflow_home"
export AIRFLOW__CORE__DAGS_FOLDER="$(pwd)/dags"
airflow scheduler
```

Open http://localhost:8080/ in your browser and sign in with the credentials you created.

## 4. Trigger the demo DAG

The DAG lives in `dags/demo_python_tasks.py`. Airflow automatically discovers it because
the `AIRFLOW_HOME` configuration points to this project.

```bash
airflow dags list
airflow dags trigger GRINDSET_EXAMPLE
airflow dags state GRINDSET_EXAMPLE "$(date +%Y-%m-%d)"  # optional
```

To pass inputs from the UI or CLI, add DAG run conf with per-task keys:

```json
{
  "task1_number": 10,
  "task1_text": "first",
  "task2_number": 20,
  "task2_text": "second",
  "task3_number": 30,
  "task3_text": "third",
  "task4_number": 40,
  "task4_text": "fourth",
  "task5_number": 50,
  "task5_text": "fifth"
}
```

In the Airflow UI: DAGs → `GRINDSET_EXAMPLE` → Actions → Trigger DAG → paste JSON in “Config”.

You can also run tasks manually for quick feedback:

```bash
airflow tasks test GRINDSET_EXAMPLE task1 "$(date +%Y-%m-%d)"
```

## Extra DAGs for looping and branching

File `dags/grindset_examples.py` provides two additional DAGs:

- `GRINDSET_LOOP`: 1 -> 2 -> 3. Task 3 re-triggers the DAG (via `TriggerDagRunOperator`) if `num <= 20` and attempts remain. Pass conf like:
  ```json
  {"num": 5, "text": "start", "attempt": 1, "max_attempts": 5}
  ```
- `GRINDSET_BRANCH`: 1 -> 2 -> 4 -> 5 or 1 -> 2 -> 4 -> 3 -> 5, controlled by `include_extra` in conf:
  ```json
  {
    "task1_num": 1, "task1_text": "one",
    "task2_num": 2, "task2_text": "two",
    "task3_num": 3, "task3_text": "three",
    "task4_num": 4, "task4_text": "four",
    "task5_num": 5, "task5_text": "five",
    "include_extra": true
  }
  ```

Each task prints clear log output, so check the Airflow UI (Graph or Grid views) or
use `airflow tasks log` to inspect what happened.

## Alternative: Airflow standalone (one command)

Airflow ships a helper for local experiments. Run this from the project root:

```bash
cd Airflow
source .venv/bin/activate
export AIRFLOW_HOME="$(pwd)/airflow_home"
export AIRFLOW__CORE__DAGS_FOLDER="$(pwd)/dags"
airflow standalone
```

The command spins up the database, webserver, scheduler, and a default admin user.
When everything is running, open the printed URL and enable the `GRINDSET_EXAMPLE` DAG.
