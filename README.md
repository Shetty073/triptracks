# TripTracks

A full-stack, intelligent road trip planner built with FastAPI, MongoDB, and Flutter.

## Features
- **Authentication**: JWT-based login/signup system with secure access and refresh tokens.
- **Profile & Crew**: Manage vehicles, trip preferences, and connect with friends.
- **Trip Intelligence**: Built-in routing and caching utilizing `geomaps-sdk` for smart trip planning and optimal route estimations based on vehicle capacities.
- **Trip Management**: Plan trips, track live locations, manage expenses dynamically (Splitwise style), and use real-time WebSockets group chat.

## Project Structure
- `/backend`: FastAPI Python application.
- `/frontend`: Flutter cross-platform mobile/web application.

## Running the Backend

### Prerequisites
- Python 3.10+
- MongoDB instance running locally or a MongoDB Atlas URI
- Memcached running locally for caching (optional but recommended for Geomaps SDK)

### Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file in the `backend` directory with the following contents:
   ```env
   SECRET_KEY=your_super_secret_jwt_key
   MONGODB_URL=mongodb://localhost:27017
   MONGODB_DB_NAME=triptracks
   GEOMAPS_API_KEY=your_geomaps_key
   MEMCACHED_SERVER=localhost:11211
   ```
5. Run the development server:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

## Running the Frontend

### Prerequisites
- Flutter SDK (latest stable)
- iOS Simulator, Android Emulator, or Chrome (for web)

### Setup
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## Security
- The backend utilizes Argon2/Bcrypt password hashing and short-lived JWTs.
- The frontend uses `flutter_secure_storage` for securely storing tokens on devices.
- CORS is restricted to local/production origins in the FastAPI configurations.
