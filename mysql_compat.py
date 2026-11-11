"""Small MySQL adapter for the application's existing execute()/Row interface.

SQL is still executed by MySQL, not SQLite. Bind values always go through the
connector. Results use floats and ISO date strings, as expected by the UI.
"""
from datetime import date, datetime
from decimal import Decimal
import re


def bind_sql(sql):
    # Skip strings, quoted identifiers and comments when translating placeholders.
    token = r"('(?:''|\\.|[^'\\])*'|\"(?:\"\"|\\.|[^\"\\])*\"|`(?:``|[^`])*`|--[^\n]*|/\*[\s\S]*?\*/)|\?|:([A-Za-z_]\w*)"
    def replace(match):
        if match.group(1):
            return match.group(0)
        return '%(' + match.group(2) + ')s' if match.group(2) else '%s'
    return re.sub(token, replace, sql)


def normalize(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, datetime):
        return value.isoformat(sep=' ')
    if isinstance(value, date):
        return value.isoformat()
    return value


class Row(dict):
    """Support both row['name'] and the legacy scalar row[0]."""
    def __getitem__(self, key):
        if isinstance(key, int):
            return tuple(self.values())[key]
        return super().__getitem__(key)


class Result:
    def __init__(self, rows, lastrowid, rowcount):
        self._rows = iter(rows)
        self.lastrowid = lastrowid
        self.rowcount = rowcount

    def fetchone(self):
        return next(self._rows, None)

    def fetchall(self):
        return list(self._rows)

    def __iter__(self):
        return self._rows


class Connection:
    def __init__(self, raw):
        self.raw = raw

    def execute(self, sql, params=()):
        cur = self.raw.cursor(dictionary=True, buffered=True)
        try:
            cur.execute(bind_sql(sql), params)
            rows = ([Row((k, normalize(v)) for k, v in row.items())
                     for row in cur.fetchall()] if cur.with_rows else [])
            return Result(rows, cur.lastrowid, cur.rowcount)
        finally:
            cur.close()

    def cursor(self, *args, **kwargs):
        return self.raw.cursor(*args, **kwargs)

    def commit(self):
        self.raw.commit()

    def rollback(self):
        self.raw.rollback()

    def close(self):
        self.raw.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        try:
            if exc_type is None:
                self.commit()
            else:
                self.rollback()
        finally:
            self.close()
