-- Table: book

-- DROP TABLE book;

CREATE TABLE book
(
  pk integer NOT NULL, -- Первичный ключ
  title character varying, -- Название книги
  author character varying, -- Имя автора
  genre character varying, -- Жанр книги
  price integer, -- Цена книги
  soc_discount boolean, -- Есть скидка на книгу
  hardcover boolean, -- Твёрдый переплёт
  CONSTRAINT key PRIMARY KEY (pk )
)
WITH (
  OIDS=FALSE
);
ALTER TABLE book
  OWNER TO postgres;
COMMENT ON COLUMN book.pk IS 'Первичный ключ';
COMMENT ON COLUMN book.title IS 'Название книги';
COMMENT ON COLUMN book.author IS 'Имя автора';
COMMENT ON COLUMN book.genre IS 'Жанр книги';
COMMENT ON COLUMN book.price IS 'Цена книги';
COMMENT ON COLUMN book.soc_discount IS 'Есть скидка на книгу';
COMMENT ON COLUMN book.hardcover IS 'Твёрдый переплёт';