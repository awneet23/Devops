const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || "nimbus",
  password: process.env.DB_PASSWORD || "nimbus123",
  database: process.env.DB_NAME || "nimbuscart",

  ssl:
    process.env.DB_SSL === "true"
      ? {
          rejectUnauthorized: false,
        }
      : false,
});

async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        stock INTEGER NOT NULL
      );
    `);

    console.log("Database initialized successfully.");
  } catch (error) {
    console.error("Database initialization failed:", error.message);
  }
}

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
  });
});

app.get("/items", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT id, name, price, stock FROM products ORDER BY id"
    );

    res.status(200).json(result.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Unable to fetch products",
    });
  }
});

app.post("/items", async (req, res) => {
  const { name, price, stock } = req.body;

  if (
    !name ||
    price === undefined ||
    stock === undefined
  ) {
    return res.status(400).json({
      error: "name, price and stock are required",
    });
  }

  try {
    const result = await pool.query(
      `INSERT INTO products (name, price, stock)
       VALUES ($1, $2, $3)
       RETURNING id, name, price, stock`,
      [name, price, stock]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Unable to add product",
    });
  }
});

app.listen(PORT, async () => {
  console.log(`NimbusCart API running on port ${PORT}`);
  await initializeDatabase();
});
