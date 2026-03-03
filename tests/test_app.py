"""
Unit tests for the Flask CI/CD Demo Application
"""

import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from app import app, add, multiply


@pytest.fixture
def client():
    """Create a test client for the Flask application"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


class TestHealthEndpoints:
    """Test health check endpoints"""

    def test_health_endpoint_returns_200(self, client):
        """Test that /health returns 200 OK"""
        response = client.get('/health')
        assert response.status_code == 200

    def test_health_endpoint_returns_healthy_status(self, client):
        """Test that /health returns healthy status"""
        response = client.get('/health')
        data = response.get_json()
        assert data['status'] == 'healthy'
        assert 'timestamp' in data

    def test_ready_endpoint_returns_200(self, client):
        """Test that /ready returns 200 OK"""
        response = client.get('/ready')
        assert response.status_code == 200

    def test_ready_endpoint_returns_true(self, client):
        """Test that /ready returns ready: true"""
        response = client.get('/ready')
        data = response.get_json()
        assert data['ready'] is True


class TestHomeEndpoint:
    """Test home page endpoint"""

    def test_home_returns_200(self, client):
        """Test that / returns 200 OK"""
        response = client.get('/')
        assert response.status_code == 200

    def test_home_returns_html(self, client):
        """Test that / returns HTML content"""
        response = client.get('/')
        assert b'CI/CD Demo App' in response.data

    def test_home_contains_container_info(self, client):
        """Test that home page contains container information"""
        response = client.get('/')
        assert b'Container Info' in response.data
        assert b'Hostname' in response.data


class TestAPIEndpoint:
    """Test API info endpoint"""

    def test_api_info_returns_200(self, client):
        """Test that /api/info returns 200 OK"""
        response = client.get('/api/info')
        assert response.status_code == 200

    def test_api_info_returns_json(self, client):
        """Test that /api/info returns JSON"""
        response = client.get('/api/info')
        assert response.content_type == 'application/json'

    def test_api_info_contains_required_fields(self, client):
        """Test that /api/info contains all required fields"""
        response = client.get('/api/info')
        data = response.get_json()
        
        required_fields = ['hostname', 'version', 'environment', 'current_time', 'status']
        for field in required_fields:
            assert field in data, f"Missing field: {field}"

    def test_api_info_status_is_running(self, client):
        """Test that /api/info status is 'running'"""
        response = client.get('/api/info')
        data = response.get_json()
        assert data['status'] == 'running'


class TestUtilityFunctions:
    """Test utility functions"""

    def test_add_positive_numbers(self):
        """Test add function with positive numbers"""
        assert add(2, 3) == 5

    def test_add_negative_numbers(self):
        """Test add function with negative numbers"""
        assert add(-2, -3) == -5

    def test_add_mixed_numbers(self):
        """Test add function with mixed numbers"""
        assert add(-2, 5) == 3

    def test_add_zero(self):
        """Test add function with zero"""
        assert add(0, 5) == 5
        assert add(5, 0) == 5

    def test_multiply_positive_numbers(self):
        """Test multiply function with positive numbers"""
        assert multiply(2, 3) == 6

    def test_multiply_negative_numbers(self):
        """Test multiply function with negative numbers"""
        assert multiply(-2, -3) == 6

    def test_multiply_mixed_numbers(self):
        """Test multiply function with mixed numbers"""
        assert multiply(-2, 5) == -10

    def test_multiply_by_zero(self):
        """Test multiply function with zero"""
        assert multiply(0, 5) == 0
        assert multiply(5, 0) == 0


class TestErrorHandling:
    """Test error handling"""

    def test_404_for_unknown_route(self, client):
        """Test that unknown routes return 404"""
        response = client.get('/unknown-route')
        assert response.status_code == 404


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
