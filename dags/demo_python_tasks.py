"""Demo DAG with five Python tasks showing fan-out/fan-in and per-task inputs."""

from __future__ import annotations

import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator


def _get_inputs(task_name: str, context, default_number: int, default_text: str):
    """Read number/text for a task from DAG run conf, falling back to defaults."""
    conf = getattr(context.get("dag_run"), "conf", {}) or {}
    number = conf.get(f"{task_name}_number", default_number)
    text = conf.get(f"{task_name}_text", default_text)
    return number, text


def _task(task_name: str, default_number: int, default_text: str, **context):
    """Generic task body that logs its inputs."""
    number, text = _get_inputs(task_name, context, default_number, default_text)
    print(f"{task_name}: number={number}, text='{text}'")


default_args = {
    "owner": "airflow-demo",
}

with DAG(
    dag_id="GRINDSET_EXAMPLE",
    default_args=default_args,
    start_date=datetime.datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["demo"],
    description="Five-task demo with fan-out/fan-in and per-task inputs",
) as dag:
    task1 = PythonOperator(
        task_id="task1",
        python_callable=_task,
        op_kwargs={"task_name": "task1", "default_number": 1, "default_text": "one"},
    )

    task2 = PythonOperator(
        task_id="task2",
        python_callable=_task,
        op_kwargs={"task_name": "task2", "default_number": 2, "default_text": "two"},
    )

    task3 = PythonOperator(
        task_id="task3",
        python_callable=_task,
        op_kwargs={"task_name": "task3", "default_number": 3, "default_text": "three"},
    )

    task4 = PythonOperator(
        task_id="task4",
        python_callable=_task,
        op_kwargs={"task_name": "task4", "default_number": 4, "default_text": "four"},
    )

    task5 = PythonOperator(
        task_id="task5",
        python_callable=_task,
        op_kwargs={"task_name": "task5", "default_number": 5, "default_text": "five"},
    )

    task1 >> task2 >> [task3, task4]
    task3 >> task5
    task4 >> task5
