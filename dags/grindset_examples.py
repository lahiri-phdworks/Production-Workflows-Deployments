"""Two DAG examples: a re-triggering loop and a branching fan-out."""

from __future__ import annotations

import pendulum
from airflow.decorators import dag, task
from airflow.operators.python import BranchPythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator


def _get_conf(context, key, default):
    """Read a value from dag_run.conf with a default."""
    conf = getattr(context.get("dag_run"), "conf", {}) or {}
    return conf.get(key, default)


@dag(
    dag_id="GRINDSET_LOOP",
    start_date=pendulum.datetime(2024, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["demo", "loop"],
    description="Example: 1->2->3, and 3 re-triggers DAG if num <= 20",
)
def grindset_loop():
    @task
    def step1(**context):
        num = int(_get_conf(context, "num", 5))
        text = str(_get_conf(context, "text", "start"))
        attempt = int(_get_conf(context, "attempt", 1))
        max_attempts = int(_get_conf(context, "max_attempts", 5))
        return {
            "num": num,
            "text": text,
            "attempt": attempt,
            "max_attempts": max_attempts,
        }

    @task
    def step2(payload: dict):
        """Pretend work; bump the number so we eventually finish."""
        payload = dict(payload)
        payload["num"] = int(payload["num"]) + 5
        return payload

    def _step3_callable(payload: dict):
        """Branch callable: decide whether to loop or finish."""
        num = int(payload["num"])
        attempt = int(payload.get("attempt", 1))
        max_attempts = int(payload.get("max_attempts", 5))
        if attempt >= max_attempts:
            return "done"
        return "done" if num > 20 else "loop"

    loop = TriggerDagRunOperator(
        task_id="loop",
        trigger_dag_id="GRINDSET_LOOP",
        reset_dag_run=True,
        conf={
            # Reuse payload from step2, bump attempt by 1
            "num": "{{ ti.xcom_pull(task_ids='step2')['num'] }}",
            "text": "{{ ti.xcom_pull(task_ids='step1')['text'] }}",
            "attempt": "{{ (ti.xcom_pull(task_ids='step1')['attempt'] | int) + 1 }}",
            "max_attempts": "{{ ti.xcom_pull(task_ids='step1')['max_attempts'] }}",
        },
    )

    @task
    def done(payload: dict):
        print(
            f"Completed after attempt {payload.get('attempt')} with num={payload.get('num')}"
        )

    p1 = step1()
    p2 = step2(p1)
    step3 = BranchPythonOperator(
        task_id="step3",
        python_callable=_step3_callable,
        op_args=[p2],
    )
    branch = step3

    branch >> loop
    branch >> done(p2)


@dag(
    dag_id="GRINDSET_BRANCH",
    start_date=pendulum.datetime(2024, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["demo", "branch"],
    description="Example: 1->2->4->5 or 1->2->4->3->5 based on conf",
)
def grindset_branch():
    @task
    def task1(**context):
        num = int(_get_conf(context, "task1_num", 1))
        text = str(_get_conf(context, "task1_text", "one"))
        print(f"task1 num={num} text='{text}'")
        return {"num": num, "text": text}

    @task
    def task2(payload: dict, **context):
        num = int(_get_conf(context, "task2_num", payload["num"] + 1))
        text = str(_get_conf(context, "task2_text", "two"))
        print(f"task2 num={num} text='{text}'")
        return {"num": num, "text": text}

    @task
    def task4(payload: dict, **context):
        num = int(_get_conf(context, "task4_num", payload["num"] + 1))
        text = str(_get_conf(context, "task4_text", "four"))
        print(f"task4 num={num} text='{text}'")
        return {"num": num, "text": text}

    @task
    def task3(payload: dict, **context):
        num = int(_get_conf(context, "task3_num", payload["num"] + 1))
        text = str(_get_conf(context, "task3_text", "three"))
        print(f"task3 num={num} text='{text}'")
        return {"num": num, "text": text}

    def _decide_callable(**context):
        include_extra = bool(_get_conf(context, "include_extra", False))
        return "task3" if include_extra else "task5"

    decide = BranchPythonOperator(task_id="decide", python_callable=_decide_callable)

    @task
    def task5(payload: dict, **context):
        num = int(_get_conf(context, "task5_num", payload.get("num", 0) + 1))
        text = str(_get_conf(context, "task5_text", "five"))
        print(f"task5 num={num} text='{text}'")

    t1 = task1()
    t2 = task2(t1)
    t4 = task4(t2)
    branch = decide
    t3 = task3(t4)
    t5 = task5(t4)

    t1 >> t2 >> t4 >> branch
    branch >> t3 >> t5
    branch >> t5


grindset_loop()
grindset_branch()
