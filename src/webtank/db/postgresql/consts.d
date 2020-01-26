module webtank.db.postgresql.consts;

enum ConnStatusType
{
	CONNECTION_OK,
	CONNECTION_BAD
}

enum ExecStatusType
{
	PGRES_EMPTY_QUERY = 0, /* empty query string was executed */
	PGRES_COMMAND_OK, /* a query command that doesn't return anything was executed properly by the backend */
	PGRES_TUPLES_OK, /* a query command that returns tuples was executed properly by the backend, PGresult contains the result tuples */
	PGRES_COPY_OUT, /* Copy Out data transfer in progress */
	PGRES_COPY_IN, /* Copy In data transfer in progress */
	PGRES_BAD_RESPONSE, /* an unexpected response was recv'd from the backend */
	PGRES_NONFATAL_ERROR, /* notice or warning message */
	PGRES_FATAL_ERROR, /* query failed */
	PGRES_COPY_BOTH, /* Copy In/Out data transfer in progress */
	PGRES_SINGLE_TUPLE /* single tuple from larger resultset */
}