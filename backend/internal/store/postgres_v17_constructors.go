package store

// V17 store URL-based constructors. The WithDB variants accept an
// existing *sql.DB; these wrappers open a fresh pool via the shared
// openPostgresPool helper (postgres_pool.go) so every store applies the
// same connection-pool ceiling.

// NewPostgresAuthTokenStore opens a fresh pool + ensures the schema.
func NewPostgresAuthTokenStore(databaseURL string) (AuthTokenStore, error) {
	db, err := openPostgresPool(databaseURL, "auth_tokens")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresAuthTokenStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

// NewPostgresStreakStore opens a fresh pool + ensures the schema.
func NewPostgresStreakStore(databaseURL string) (StreakStore, error) {
	db, err := openPostgresPool(databaseURL, "streak_days")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresStreakStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

// NewPostgresProPurchaseStore opens a fresh pool + ensures the schema.
func NewPostgresProPurchaseStore(databaseURL string) (ProPurchaseStore, error) {
	db, err := openPostgresPool(databaseURL, "pro_purchases")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresProPurchaseStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

// NewPostgresDailyUsageStore opens a fresh pool + ensures the schema.
func NewPostgresDailyUsageStore(databaseURL string) (DailyUsageStore, error) {
	db, err := openPostgresPool(databaseURL, "daily_usage")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresDailyUsageStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

// NewPostgresSkillMasteryStore opens a fresh pool + ensures the V19
// user_skill_mastery schema.
func NewPostgresSkillMasteryStore(databaseURL string) (SkillMasteryStore, error) {
	db, err := openPostgresPool(databaseURL, "user_skill_mastery")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresSkillMasteryStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}
