from fastapi.testclient import TestClient

from app import main


client = TestClient(main.app)


def setup_function() -> None:
    main.tasks.clear()
    main.next_task_id = 1


def test_create_task() -> None:
    response = client.post(
        "/tasks",
        json={
            "title": "Aprender Docker",
            "description": "Entender imágenes y contenedores",
        },
    )

    assert response.status_code == 201
    assert response.json() == {
        "id": 1,
        "title": "Aprender Docker",
        "description": "Entender imágenes y contenedores",
        "completed": False,
    }


def test_list_tasks() -> None:
    client.post(
        "/tasks",
        json={
            "title": "Aprender Docker",
            "description": None,
        },
    )

    response = client.get("/tasks")

    assert response.status_code == 200
    assert response.json() == [
        {
            "id": 1,
            "title": "Aprender Docker",
            "description": None,
            "completed": False,
        }
    ]


def test_reject_task_without_title() -> None:
    response = client.post(
        "/tasks",
        json={
            "title": "",
            "description": "Esta tarea no debería crearse",
        },
    )

    assert response.status_code == 422

def test_get_task_by_id() -> None:
    client.post(
        "/tasks",
        json={
            "title": "Aprender FastAPI",
            "description": None,
        },
    )

    response = client.get("/tasks/1")

    assert response.status_code == 200
    assert response.json() == {
        "id": 1,
        "title": "Aprender FastAPI",
        "description": None,
        "completed": False,
    }


def test_get_missing_task_returns_404() -> None:
    response = client.get("/tasks/999")

    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}
    

def test_update_task() -> None:
    client.post(
        "/tasks",
        json={
            "title": "Aprender testing",
            "description": None,
        },
    )

    response = client.patch(
        "/tasks/1",
        json={"completed": True},
    )

    assert response.status_code == 200
    assert response.json() == {
        "id": 1,
        "title": "Aprender testing",
        "description": None,
        "completed": True,
    }


def test_update_missing_task_returns_404() -> None:
    response = client.patch(
        "/tasks/999",
        json={"completed": True},
    )

    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}

def test_delete_task() -> None:
    client.post(
        "/tasks",
        json={
            "title": "Tarea para eliminar",
            "description": None,
        },
    )

    delete_response = client.delete("/tasks/1")

    assert delete_response.status_code == 204
    assert delete_response.content == b""

    get_response = client.get("/tasks/1")

    assert get_response.status_code == 404


def test_delete_missing_task_returns_404() -> None:
    response = client.delete("/tasks/999")

    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}