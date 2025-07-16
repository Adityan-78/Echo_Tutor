import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'echo.db');

      return await openDatabase(
        path,
        version: 7, // Increment version for new table and columns
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print("❌ Database error: $e");
      throw Exception("Failed to initialize database");
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        streak INTEGER DEFAULT 0,
        xp INTEGER DEFAULT 0,
        last_login TEXT DEFAULT NULL,
        full_name TEXT DEFAULT NULL,
        age INTEGER DEFAULT NULL,
        total_learning_time INTEGER DEFAULT 0, -- New column for tracking learning time (in minutes)
        total_quiz_time INTEGER DEFAULT 0,    -- New column for tracking quiz time (in minutes)
        lessons_completed INTEGER DEFAULT 0,  -- New column for tracking lessons completed
        translations_performed INTEGER DEFAULT 0 -- New column for tracking translations
      )
    ''');

    await db.execute('''
      CREATE TABLE preferences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_email TEXT NOT NULL,
        theme TEXT DEFAULT 'light',
        FOREIGN KEY (user_email) REFERENCES users(email)
      )
    ''');

    await db.execute('''
      CREATE TABLE achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_email TEXT NOT NULL,
        achievement_id TEXT NOT NULL, -- Unique identifier for the achievement (e.g., "login_streak_5")
        title TEXT NOT NULL,
        completed INTEGER DEFAULT 0,  -- 0 for not completed, 1 for completed
        progress INTEGER DEFAULT 0,   -- Progress towards the goal (e.g., current streak, time spent)
        goal INTEGER NOT NULL,       -- Target goal (e.g., 5 days for streak)
        xp_reward INTEGER NOT NULL,  -- XP awarded upon completion
        type TEXT NOT NULL,          -- "hardcoded" or "gemini"
        FOREIGN KEY (user_email) REFERENCES users(email)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE users ADD COLUMN streak INTEGER DEFAULT 0");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE users ADD COLUMN xp INTEGER DEFAULT 0");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE users ADD COLUMN last_login TEXT DEFAULT NULL");
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE users ADD COLUMN full_name TEXT DEFAULT NULL");
      await db.execute("ALTER TABLE users ADD COLUMN age INTEGER DEFAULT NULL");
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE preferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_email TEXT NOT NULL,
          theme TEXT DEFAULT 'light',
          FOREIGN KEY (user_email) REFERENCES users(email)
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE users ADD COLUMN total_learning_time INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE users ADD COLUMN total_quiz_time INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE users ADD COLUMN lessons_completed INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE users ADD COLUMN translations_performed INTEGER DEFAULT 0");
      await db.execute('''
        CREATE TABLE achievements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_email TEXT NOT NULL,
          achievement_id TEXT NOT NULL,
          title TEXT NOT NULL,
          completed INTEGER DEFAULT 0,
          progress INTEGER DEFAULT 0,
          goal INTEGER NOT NULL,
          xp_reward INTEGER NOT NULL,
          type TEXT NOT NULL,
          FOREIGN KEY (user_email) REFERENCES users(email)
        )
      ''');
    }
  }

  Future<bool> userExists(String email) async {
    final db = await instance.database;
    final result = await db.query(
      "users",
      where: "email = ?",
      whereArgs: [email],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> insertUser(String username, String email, String password) async {
    final db = await instance.database;
    final userId = await db.insert(
      "users",
      {
        "username": username,
        "email": email,
        "password": password,
        "streak": 0,
        "xp": 0,
        "last_login": null,
        "full_name": null,
        "age": null,
        "total_learning_time": 0,
        "total_quiz_time": 0,
        "lessons_completed": 0,
        "translations_performed": 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      "preferences",
      {
        "user_email": email,
        "theme": "light",
      },
    );

    return userId;
  }

  Future<Map<String, dynamic>?> getUser(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      "users",
      where: "email = ? AND password = ?",
      whereArgs: [email, password],
      limit: 1,
    );
    if (result.isNotEmpty) {
      await _updateLoginStreak(email);
      return result.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await instance.database;
    final result = await db.query(
      "users",
      where: "email = ?",
      whereArgs: [email],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> _updateLoginStreak(String email) async {
    final db = await database;
    final user = await getUserByEmail(email);
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLoginStr = user['last_login'] as String?;
    final lastLogin = lastLoginStr != null ? DateTime.parse(lastLoginStr) : null;
    int currentStreak = user['streak'] ?? 0;

    if (lastLogin == null) {
      currentStreak = 1;
    } else {
      final lastLoginDay = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
      final difference = today.difference(lastLoginDay).inDays;
      if (difference == 1) {
        currentStreak += 1;
      } else if (difference > 1) {
        currentStreak = 1;
      } else if (difference == 0) {
        return;
      }
    }

    await db.update(
      "users",
      {
        "streak": currentStreak,
        "last_login": today.toIso8601String(),
      },
      where: "email = ?",
      whereArgs: [email],
    );
  }

  Future<void> updateUserXp(String email, int xpIncrement) async {
    final db = await database;
    final currentUser = await getUserByEmail(email);
    if (currentUser != null) {
      final newXp = (currentUser['xp'] ?? 0) + xpIncrement;
      await db.update(
        'users',
        {'xp': newXp},
        where: 'email = ?',
        whereArgs: [email],
      );
    }
  }

  Future<void> updateUserStreak(String email, int streak) async {
    final db = await database;
    await db.update(
      'users',
      {'streak': streak},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<void> updateUserDetails(String email, String fullName, int? age) async {
    final db = await database;
    await db.update(
      "users",
      {
        "full_name": fullName,
        "age": age,
      },
      where: "email = ?",
      whereArgs: [email],
    );
  }

  // New methods for tracking progress
  Future<void> updateLearningTime(String email, int minutes) async {
    final db = await database;
    final user = await getUserByEmail(email);
    if (user != null) {
      final newTime = (user['total_learning_time'] ?? 0) + minutes;
      await db.update(
        'users',
        {'total_learning_time': newTime},
        where: 'email = ?',
        whereArgs: [email],
      );
    }
  }

  Future<void> updateQuizTime(String email, int minutes) async {
    final db = await database;
    final user = await getUserByEmail(email);
    if (user != null) {
      final newTime = (user['total_quiz_time'] ?? 0) + minutes;
      await db.update(
        'users',
        {'total_quiz_time': newTime},
        where: 'email = ?',
        whereArgs: [email],
      );
    }
  }

  Future<void> incrementLessonsCompleted(String email) async {
    final db = await database;
    final user = await getUserByEmail(email);
    if (user != null) {
      final newCount = (user['lessons_completed'] ?? 0) + 1;
      await db.update(
        'users',
        {'lessons_completed': newCount},
        where: 'email = ?',
        whereArgs: [email],
      );
    }
  }

  Future<void> incrementTranslationsPerformed(String email) async {
    final db = await database;
    final user = await getUserByEmail(email);
    if (user != null) {
      final newCount = (user['translations_performed'] ?? 0) + 1;
    await      db.update(
      'users',
      {'translations_performed': newCount},
      where: 'email = ?',
      whereArgs: [email],
    );
    }
  }

  // Methods for managing achievements
  Future<void> insertAchievement({
    required String userEmail,
    required String achievementId,
    required String title,
    required int goal,
    required int xpReward,
    required String type,
  }) async {
    final db = await database;
    await db.insert(
      'achievements',
      {
        'user_email': userEmail,
        'achievement_id': achievementId,
        'title': title,
        'completed': 0,
        'progress': 0,
        'goal': goal,
        'xp_reward': xpReward,
        'type': type,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getAchievements(String userEmail, String type) async {
    final db = await database;
    return await db.query(
      'achievements',
      where: 'user_email = ? AND type = ?',
      whereArgs: [userEmail, type],
    );
  }

  Future<void> updateAchievementProgress(String userEmail, String achievementId, int progress) async {
    final db = await database;
    final achievement = await db.query(
      'achievements',
      where: 'user_email = ? AND achievement_id = ?',
      whereArgs: [userEmail, achievementId],
      limit: 1,
    );

    if (achievement.isNotEmpty) {
      final current = achievement.first;
      final goal = current['goal'] as int;
      final completed = current['completed'] as int;
      if (completed == 1) return; // Already completed

      final newProgress = progress > goal ? goal : progress;
      final isNowCompleted = newProgress >= goal;

      await db.update(
        'achievements',
        {
          'progress': newProgress,
          'completed': isNowCompleted ? 1 : 0,
        },
        where: 'user_email = ? AND achievement_id = ?',
        whereArgs: [userEmail, achievementId],
      );

      if (isNowCompleted) {
        final xpReward = current['xp_reward'] as int;
        await updateUserXp(userEmail, xpReward);
      }
    }
  }

  Future<String> getThemePreference(String email) async {
    final db = await database;
    final result = await db.query(
      "preferences",
      where: "user_email = ?",
      whereArgs: [email],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['theme'] as String : 'light';
  }

  Future<void> updateThemePreference(String email, String theme) async {
    final db = await database;
    await db.update(
      "preferences",
      {"theme": theme},
      where: "user_email = ?",
      whereArgs: [email],
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}