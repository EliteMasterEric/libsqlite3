package sqlite;

#if cpp
import cpp.Char;
import cpp.ConstPointer;
import cpp.NativeString;
import cpp.RawConstPointer;
import cpp.Stdlib;
import cpp.NativeArray;
import haxe.io.Bytes;
import haxe.Int64;
import cpp.Pointer;
import cpp.Callable;
import cpp.vm.Gc;
import sqlite._internal.RawSQLite.*;
import sqlite._internal.RawSQLiteStatement;
import haxe.ds.Vector;

/**
 * Represents a prepared SQL statement to be performed.
 * 
 * NOTES:
 * - Bind values and execute the query rather than concatenating strings to avoid SQL injection attacks.
 * - Call `executeStatement()` to ignore results or `executeQuery()` to get result rows to iterate over.
 * - Call `clearBindings()` and you can bind new values and reuse the query object!
 * @see https://www.sqlite.org/cintro.html
 */
@:unreflective
@:allow(sqlite.SQLiteDatabase)
class SQLiteStatement
{
  /**
   * The database connection associated with this statement.
   */
  private var owner:SQLiteDatabase;

  /**
   * The C extern to interact with the SQLite statement.
   */
  private var statement:Pointer<RawSQLiteStatement>;

  /**
   * If `sqlite3_step` already threw an error, prevent `reset()` from throwing again.
   */
  private var stepErrorThrown:Bool = false;

  /**
   * Increments every time `reset()` gets called.
   */
  private var execution:Int = 0;

  private function new(owner:SQLiteDatabase,
    statement:Pointer<RawSQLiteStatement>)
  {
    this.owner = owner;
    this.statement = statement;
    // Set a function to call when garbage collecting this object.
    Gc.setFinalizer(this, Callable.fromStaticFunction(onCollected));
  }

  /**
   * Guarantee the extern statement gets finalized and cleaned up
   * when garbage collecting this object.
   */
  @:void
  private static function onCollected(stmt:SQLiteStatement):Void
  {
    if (stmt.statement != null)
    {
      sqlite3_finalize(stmt.statement.raw);
      stmt.statement = null;
    }
  }

  /**
   * Finalize the statement and frees its resources.
   * It cannot be reused after this.
   */
  public function close():Void
  {
    if (statement == null) return;

    sqlite3_finalize(statement.raw);
    owner.onStatementClosed(this);
    this.owner = null;
    this.statement = null;
  }

  /**
   * Resets the statement so it can be bound and executed again. Bound values are kept.
   * Iterators returned by earlier `executeQuery()` calls throw after this.
   * Throws a step error of the last execution that was not already thrown.
   */
  public function reset():SQLiteStatement
  {
    checkOpen();

    execution++;
    var result:SQLiteResultCode = sqlite3_reset(statement.raw);

    var alreadyThrown = stepErrorThrown;
    stepErrorThrown = false;
    if (result != SQLiteResultCode.OK && !alreadyThrown)
    {
      throw SQLiteException.fromConnection(owner.db.raw);
    }

    return this;
  }

  /**
   * Bind the `index`th parameter with the provided value, as a 32-bit number (or `NULL` if the input is null).
   * 
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if `index` is out of range, `MISUSE` if the statement has run since `reset()`.
   */
  public function bindInt(index:Int, value:Null<Int>):SQLiteStatement
  {
    checkBindable(index);
    // Nullable, since on hxcpp a null passed as a plain Int silently becomes 0.
    if (value == null) return bindNull(index);

    var result:SQLiteResultCode = sqlite3_bind_int(statement.raw, index, value);
    checkBindResult(result);

    return this;
  }

  /**
   * Bind the `index`th parameter with the provided value, as a 64-bit number (or `NULL` if the input is null).
   * 
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if `index` is out of range, `MISUSE` if the statement has run since `reset()`.
   */
  public function bindInt64(index:Int, value:Null<Int64>):SQLiteStatement
  {
    checkBindable(index);
    if (value == null) return bindNull(index);

    var result:SQLiteResultCode = sqlite3_bind_int64(statement.raw, index, value);
    checkBindResult(result);

    return this;
  }

  /**
   * Bind the `index`th parameter with the provided value, as a floating point value (or `NULL` if the input is null).
   * 
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if `index` is out of range, `MISUSE` if the statement has run since `reset()`.
   */
  public function bindFloat(index:Int, value:Null<Float>):SQLiteStatement
  {
    checkBindable(index);
    if (value == null) return bindNull(index);

    var result:SQLiteResultCode = sqlite3_bind_double(statement.raw, index, value);
    checkBindResult(result);

    return this;
  }

  /**
   * Bind the `index`th parameter with the provided value, as a string (or `NULL` if the input is null).
   * 
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if `index` is out of range, `MISUSE` if the statement has run since `reset()`.
   */
  public function bindString(index:Int, value:Null<String>):SQLiteStatement
  {
    checkBindable(index);
    if (value == null) return bindNull(index);

    // Convert the string to bytes to prevent issues with 0x0 / non-ASCII characters.
    var utf8 = Bytes.ofString(value);
    if (utf8.length == 0)
    {
      var result:SQLiteResultCode = sqlite3_bind_text(statement.raw, index, "", 0, SQLITE_TRANSIENT);
      checkBindResult(result);
    }
    else
    {
      var p:Pointer<Char> = NativeArray.address(utf8.getData(), 0).reinterpret();
      var result:SQLiteResultCode = sqlite3_bind_text(statement.raw, index, cast p.raw, utf8.length, SQLITE_TRANSIENT);
      checkBindResult(result);
    }
    return this;
  }

  /**
   * Bind the `index`th parameter with the provided value, as a binary blob (or `NULL` if the input is null).
   * 
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if `index` is out of range, `MISUSE` if the statement has run since `reset()`.
   */
  public function bindBytes(index:Int, value:Null<Bytes>):SQLiteStatement
  {
    checkBindable(index);
    if (value == null) return bindNull(index);

    var result:SQLiteResultCode;
    if (value.length == 0)
    {
      // Bind a zero blob instead of using NativeArray to prevent the array from auto-growing.
      result = sqlite3_bind_zeroblob(statement.raw, index, 0);
    }
    else
    {
      var p:Pointer<cpp.Void> = NativeArray.address(value.getData(), 0).reinterpret();
      result = sqlite3_bind_blob(statement.raw, index, p.raw, value.length, SQLITE_TRANSIENT);
    }
    checkBindResult(result);
    return this;
  }

  /**
   * Binds the `index`th parameter with `NULL`.
   *
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if `index` is out of range, `MISUSE` if the statement has run since `reset()`.
   */
  public function bindNull(index:Int):SQLiteStatement
  {
    checkBindable(index);

    var result:SQLiteResultCode = sqlite3_bind_null(statement.raw, index);
    checkBindResult(result);
    return this;
  }

  /**
   * Bind the `index`th parameter with the provided value, as `TRUE` or `FALSE` (or `NULL`).
   * The type in the table will be `INTEGER` since there is no boolean type.
   *
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if `index` is out of range, `MISUSE` if the statement has run since `reset()`.
   */
  public function bindBool(index:Int, value:Null<Bool>):SQLiteStatement
  {
    if (value == null) return bindNull(index);
    return bindInt(index, value ? 1 : 0);
  }

  /**
   * Check before binding a numbered parameter, and provide a specific error message if it fails.
   */
  private function checkBindable(index:Int):Void
  {
    checkOpen();
    var parameterCount:Int = sqlite3_bind_parameter_count(statement.raw);
    if (index < 1 || index > parameterCount)
    {
      throw new SQLiteException(
        'Parameter index $index is out of range; the statement has $parameterCount parameters, numbered from 1',
        SQLiteResultCode.RANGE
      );
    }
  }

  /**
   * Throws the error from a failed `sqlite3_bind_*` call.
   */
  private function checkBindResult(result:SQLiteResultCode):Void
  {
    if (result == SQLiteResultCode.OK) return;

    // MISUSE indicates the statement was already executed and needs to be reset.
    // sqlite3_stmt_busy() only returns true if the statement is CURRENTLY running so this is the next best thing.
    if (result == SQLiteResultCode.MISUSE)
    {
      throw new SQLiteException("Cannot bind while the statement is running or after it has run; call reset() first", SQLiteResultCode.MISUSE);
    }
    throw SQLiteException.fromConnection(owner.db.raw);
  }

  /**
   * Bind the named parameter with the provided value, as a 32-bit number (or `NULL` if the input is null).
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindIntByName(name:String, value:Null<Int>):SQLiteStatement
  {
    return bindInt(parameterIndex(name), value);
  }

  /**
   * Bind the named parameter with the provided value, as a 64-bit number (or `NULL` if the input is null).
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindInt64ByName(name:String, value:Null<Int64>):SQLiteStatement
  {
    return bindInt64(parameterIndex(name), value);
  }

  /**
   * Bind the named parameter with the provided value, as a floating point value (or `NULL` if the input is null).
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindFloatByName(name:String, value:Null<Float>):SQLiteStatement
  {
    return bindFloat(parameterIndex(name), value);
  }

  /**
   * Bind the named parameter with the provided value, as a string (or `NULL` if the input is null).
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindStringByName(name:String, value:Null<String>):SQLiteStatement
  {
    return bindString(parameterIndex(name), value);
  }

  /**
   * Bind the named parameter with the provided value, as a binary blob (or `NULL` if the input is null).
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindBytesByName(name:String, value:Null<Bytes>):SQLiteStatement
  {
    return bindBytes(parameterIndex(name), value);
  }

  /**
   * Binds the named parameter with `NULL`.
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindNullByName(name:String):SQLiteStatement
  {
    return bindNull(parameterIndex(name));
  }

  /**
   * Bind the named parameter with the provided value, as `TRUE` or `FALSE` (or `NULL` if the input is null).
   * The table stores the value as an integer.
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindBoolByName(name:String, value:Null<Bool>):SQLiteStatement
  {
    return bindBool(parameterIndex(name), value);
  }

  /**
   * Bind the `index`th parameter with the provided value.
   * The type of `value` is checked at runtime and the appropriate function is called.
   *
   * @return Self, for chaining calls.
   * @throws SQLiteException `MISUSE` if the value has another type.
   */
  public function bind(index:Int, value:Any):SQLiteStatement
  {
    return bindValue(index, toBindValue(value));
  }

  /**
   * Choose the bind for a value from its runtime type.
   * This allows `bindAll()` to check every value before binding anything.
   */
  private static function toBindValue(value:Any):BindValue
  {
    // Type.typeof() tells Int and Float apart on hxcpp, Std.isOfType does not.
    switch (Type.typeof(value))
    {
      case TNull:
        return BNull;
      case TInt:
        return BInt(value);
      case TFloat:
        return BFloat(value);
      case TBool:
        return BInt((value : Bool) ? 1 : 0);
      case TClass(_) if (value is String):
        return BString(value);
      case TClass(_) if (value is Bytes):
        return BBytes(value);
      // An Int64 that fits in 32 bits is a TInt; only larger ones get here.
      case TClass(_) if (Int64.isInt64(value)):
        return BInt64(value);
      case other:
        throw new SQLiteException('Can\'t bind a value of type $other; use Int, Int64, Float, Bool, String, Bytes or null', SQLiteResultCode.MISUSE);
    }
  }

  /**
   * Bind a value appropriately based on its type.
   */
  private function bindValue(index:Int, value:BindValue):SQLiteStatement
  {
    return switch (value)
    {
      case BNull:
        bindNull(index);
      case BInt(v):
        bindInt(index, v);
      case BInt64(v):
        bindInt64(index, v);
      case BFloat(v):
        bindFloat(index, v);
      case BString(v):
        bindString(index, v);
      case BBytes(v):
        bindBytes(index, v);
    }
  }

  /**
   * Bind the named parameter with the provided value.
   * The type of `value` is checked at runtime and the appropriate function is called.
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name,
   *   `MISUSE` if the value has a type `bind()` doesn't support.
   */
  public function bindByName(name:String, value:Any):SQLiteStatement
  {
    return bind(parameterIndex(name), value);
  }

  /**
   * Bind the `index`th parameter with the provided value, converted to JSON text (or `NULL` if the input is null).
   *
   * Wrap the parameter in `json(?)` in the SQL query to perform json operations on it.
   * NOTE: Don't pass a `String` in here, or else it will be JSON.stringify'd twice.
   *
   * @return Self, for chaining calls.
   */
  public function bindJson(index:Int, value:Any):SQLiteStatement
  {
    return bindString(index, value == null ? null : haxe.Json.stringify(value));
  }

  /**
   * Bind the named parameter with the provided value, converted to JSON text.
   *
   * @param name The parameter's name including its prefix, such as `":id"`, `"@id"` or `"$id"`.
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the statement has no parameter with that name.
   */
  public function bindJsonByName(name:String, value:Any):SQLiteStatement
  {
    return bindJson(parameterIndex(name), value);
  }

  /**
   * Bind every parameter in order, `values[0]` to parameter 1 and so on.
   * The type of `value` is checked at runtime and the appropriate function is called.
   * Named parameters are numbered in order of first appearance, so this binds them too.
   *
   * Every value is checked before any is bound, so an error leaves the earlier bindings in place.
   *
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if the number of values doesn't match the number of parameters,
   *   `MISUSE` if a value has a type `bind()` doesn't support.
   */
  public function bindAll(values:Array<Any>):SQLiteStatement
  {
    checkOpen();
    if (values == null) throw new SQLiteException("Values array is null", SQLiteResultCode.MISUSE);
    // An unbound parameter would silently keep its previous value (or NULL), so require one value for each.
    var parameterCount:Int = sqlite3_bind_parameter_count(statement.raw);
    if (values.length != parameterCount)
    {
      throw new SQLiteException('Got ${values.length} values for a statement with $parameterCount parameters', SQLiteResultCode.RANGE);
    }

    var bindValues:Array<BindValue> = [for (value in values) toBindValue(value)];
    for (i => value in bindValues)
    {
      bindValue(i + 1, value);
    }
    return this;
  }

  /**
   * Bind every parameter by name.
   * The map must have exactly one value for each named parameter, with names including their prefix.
   * Example: `[":name" => "Bob", ":age" => 25]`.
   * Every pair is checked before any is bound, so an error leaves the earlier bindings in place.
   *
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if a parameter has no value, a name isn't a parameter of the statement,
   *   or the statement has a positional parameter (bind those with `bindAll()` or `bind()`).
   *   `MISUSE` if a value has a type `bind()` doesn't support.
   */
  public function bindAllByName(values:Map<String, Any>):SQLiteStatement
  {
    checkOpen();
    if (values == null) throw new SQLiteException("Values map is null", SQLiteResultCode.MISUSE);

    // Names are matched only by SQLite, never by looking up a name SQLite returns in a Map or object:
    // on hxcpp 4.3.2, hashed lookups of equal non-ASCII strings can fail depending on how each string was made.
    var bindings:Array<Binding> = [for (name => value in values) {
      index: parameterIndex(name),
      value: toBindValue(value)
    }];
    checkEveryParameterBound(bindings);

    for (binding in bindings)
    {
      bindValue(binding.index, binding.value);
    }
    return this;
  }

  /**
   * Bind every parameter from the fields of an anonymous structure, choosing each bind as `bind()` does.
   * A field matches the parameter with its name and ANY prefix, so `{name: "Bob", age: 25}` binds `:name` or `@age`.
   * 
   * The structure must have exactly one field for each named parameter.
   * Every field is checked before any is bound, so an error leaves the earlier bindings in place.
   *
   * @return Self, for chaining calls.
   * @throws SQLiteException `RANGE` if a parameter has no field, a field doesn't match a parameter,
   *   or the statement has a positional or numbered parameter (`?`, `?1`; bind those with `bindAll()` or `bind()`).
   *   `MISUSE` if `values` isn't an anonymous structure, a value has a type `bind()` doesn't support,
   *   or two parameters differ only in their prefix (such as `:name` and `@name`).
   */
  public function bindObject(values:Any):SQLiteStatement
  {
    checkOpen();
    if (!Type.typeof(values).match(TObject))
    {
      throw new SQLiteException('bindObject() needs an anonymous structure, got ${Type.typeof(values)}', SQLiteResultCode.MISUSE);
    }

    // Match each field to its parameter through SQLite, as bindAllByName() does, trying every prefix.
    var bindings:Array<Binding> = [];
    for (field in Reflect.fields(values))
    {
      var index:Int = 0;
      for (prefix in [":", "@", "$"])
      {
        var prefixedIndex:Int = parameterIndexOrZero(prefix + field);
        if (prefixedIndex == 0) continue;
        if (index != 0)
        {
          throw new SQLiteException('More than one parameter is named "$field" with different prefixes; bind them with bindByName()', SQLiteResultCode.MISUSE);
        }
        index = prefixedIndex;
      }
      if (index == 0) throw new SQLiteException('Field "$field" doesn\'t match a parameter', SQLiteResultCode.RANGE);
      bindings.push({
        index: index,
        value: toBindValue(Reflect.field(values, field))
      });
    }
    checkEveryParameterBound(bindings);

    for (binding in bindings)
    {
      bindValue(binding.index, binding.value);
    }
    return this;
  }

  /**
   * Checks that `bindings` has a value for every parameter of the statement.
   * An unbound parameter would silently keep its previous value (or NULL).
   *
   * @throws SQLiteException `RANGE` if a parameter has no value, or no name (a `?`, or a gap left by a numbered parameter such as `?3`).
   */
  private function checkEveryParameterBound(bindings:Array<Binding>):Void
  {
    var parameterCount:Int = sqlite3_bind_parameter_count(statement.raw);
    var bound:Vector<Bool> = new Vector<Bool>(parameterCount + 1);
    for (binding in bindings)
    {
      bound[binding.index] = true;
    }

    for (i in 1...parameterCount + 1)
    {
      if (bound[i]) continue;
      var name:Null<String> = sqlite3_bind_parameter_name(statement.raw, i);
      if (name == null)
      {
        throw new SQLiteException('Parameter $i has no name; bind positional parameters with bindAll() or bind()', SQLiteResultCode.RANGE);
      }
      throw new SQLiteException('No value for parameter "$name"', SQLiteResultCode.RANGE);
    }
  }

  /**
   * Look up the numeric index of a named parameter, starting at `1`.
   * A name used more than once in the SQL has one index, so binding it sets every use.
   * 
   * @throws SQLiteException `RANGE` if the statement has none with that name.
   */
  private function parameterIndex(name:String):Int
  {
    var index:Int = parameterIndexOrZero(name);
    if (index == 0)
    {
      var hint:String = ~/^[:@$?]/.match(name) ? "" : '; include its prefix, such as ":$name"';
      throw new SQLiteException('No parameter named "$name" in the statement$hint', SQLiteResultCode.RANGE);
    }
    return index;
  }

  /**
   * Look up the numeric index of a named parameter, starting at `1`.
   * 
   * @return The index, or `0` if the statement has none with that name.
   */
  private function parameterIndexOrZero(name:String):Int
  {
    checkOpen();
    if (name == null) throw new SQLiteException("Parameter name is null", SQLiteResultCode.MISUSE);
    // The name is passed as a C string, which would end at a NUL and match a shorter name.
    if (name.indexOf("\x00") != -1) throw new SQLiteException("Parameter name contains a NUL character", SQLiteResultCode.MISUSE);

    return sqlite3_bind_parameter_index(statement.raw, name);
  }

  /**
   * Sets every parameter back to `NULL`.
   * `reset()` resets the statement while keeping bound values,
   * so call this to reuse the prepared statement with new values!.
   * 
   * Throws if the statement is in the middle of executing, make sure to call `reset()` first.
   * @return Self, for chaining calls.
   */
  public function clearBindings():SQLiteStatement
  {
    checkOpen();

    // A running statement holds shallow copies of its bound values, which clearing them would free.
    if (sqlite3_stmt_busy(statement.raw) != 0)
    {
      throw new SQLiteException("Cannot clear bindings while the statement is executing; call reset() first", SQLiteResultCode.MISUSE);
    }

    // Always returns SQLITE_OK for a valid statement.
    sqlite3_clear_bindings(statement.raw);
    return this;
  }

  /**
   * Resets the statement and runs it to completion.
   * Any rows it returns are discarded, use `executeQuery()` if you care about the results.
   */
  public function executeStatement():Void
  {
    reset();

    var result:SQLiteResultCode = step();
    while (result == SQLiteResultCode.ROW)
    {
      result = step();
    }
    if (result != SQLiteResultCode.DONE) throwStepError(SQLiteException.fromConnection(owner.db.raw));
  }

  /**
   * Advance the statement to the next result row.
   */
  private function step():SQLiteResultCode
  {
    stepErrorThrown = false;
    return sqlite3_step(statement.raw);
  }

  /**
   * Throw an error resulting from a call to `sqlite3_step()`,
   * then remember we did that so `sqlite3_reset()` doesn't rethrow the same error.
   */
  private function throwStepError(error:SQLiteException):Void
  {
    stepErrorThrown = true;
    throw error;
  }

  private function checkOpen():Void
  {
    if (statement == null) throw new SQLiteException("Statement is closed", SQLiteResultCode.MISUSE);
  }

  /**
   * Resets the statement and runs it with the bound parameters.
   * 
   * @returns An `Iterator<Dynamic>` over each row in the query results.
   * 	 The rows are anonymous structures, where each column is a field on the object.
   * @throws SQLiteException `MISUSE` if two result columns have the same name (such as from a join), use `AS` to alias.
   */
  public function executeQuery():Iterator<Dynamic>
  {
    reset();
    var thisExecution:Int = execution;

    var status:SQLiteResultCode = step();
    if (status != SQLiteResultCode.ROW && status != SQLiteResultCode.DONE) throwStepError(SQLiteException.fromConnection(owner.db.raw));

    // Read the columns after the first step, since that step recompiles the statement if the schema changed.
    var columnCount = sqlite3_column_count(statement.raw);
    var columnNames = new Vector<String>(columnCount);
    var seenNames:Array<String> = [];
    for (i in 0...columnCount)
    {
      var name:String = sqlite3_column_name(statement.raw, i);
      // Rows are keyed by column name, so a second column with the same name would overwrite the first.
      if (seenNames.contains(name))
      {
        // Don't leave the statement mid-execution, holding its read lock.
        reset();
        throw new SQLiteException('Duplicate column name "$name" in the query result; give the columns distinct names with AS', SQLiteResultCode.MISUSE);
      }
      seenNames.push(name);
      columnNames[i] = name;
    }

    // An error fetching the next row is kept and thrown by the next `hasNext()` or `next()` call,
    // so the row already fetched is still returned.
    // It is read when the row fails, since later calls on the connection replace the connection's error.
    var nextRowError:Null<SQLiteException> = null;

    function checkCurrent():Void
    {
      checkOpen();
      if (execution != thisExecution)
      {
        throw new SQLiteException("Iterator is out of date: its statement was reset or executed again", SQLiteResultCode.MISUSE);
      }
      if (nextRowError != null) throwStepError(nextRowError);
    }

    // Returns an Iterator, which provides hasNext() and next().
    // You can loop over this to fetch values one at a time as needed,
    // or use Lambda.array() to just get an Array of values.
    return {
      hasNext: () ->
      {
        checkCurrent();
        return status == SQLiteResultCode.ROW;
      },
      next: () ->
      {
        checkCurrent();

        switch (status)
        {
          case DONE:
            // We've already read the last row in the query results.
            return null;

          case ROW:
            // Read the next row in the query results.
            var data:Dynamic = {};
            for (i in 0...columnCount)
            {
              var type:SQLiteColumnType = sqlite3_column_type(statement.raw, i);
              switch (type)
              {
                case INTEGER:
                  // An `Int` when the value fits in 32 bits, otherwise an `Int64`.
                  var value:Int64 = sqlite3_column_int64(statement.raw, i);
                  if (value.high == value.low >> 31)
                  {
                    Reflect.setField(data, columnNames[i], value.low);
                  }
                  else
                  {
                    Reflect.setField(data, columnNames[i], value);
                  }
                case FLOAT:
                  Reflect.setField(data, columnNames[i], sqlite3_column_double(statement.raw, i));
                case TEXT:
                  var text:ConstPointer<Char> = ConstPointer.fromRaw(sqlite3_column_text(statement.raw, i)).reinterpret();
                  var textBytes:Int = sqlite3_column_bytes(statement.raw, i);
                  Reflect.setField(data, columnNames[i], NativeString.fromPointerLen(text, textBytes));
                case BLOB:
                  var blob:RawConstPointer<cpp.UInt8> = cast sqlite3_column_blob(statement.raw, i);
                  var size:Int = sqlite3_column_bytes(statement.raw, i);
                  var bytes = Bytes.alloc(size);
                  if (size > 0)
                  {
                    var dest:Pointer<cpp.Void> = NativeArray.address(bytes.getData(), 0).reinterpret();
                    Stdlib.nativeMemcpy(dest.raw, cast blob, size);
                  }
                  Reflect.setField(data, columnNames[i], bytes);
                case NULL:
                  Reflect.setField(data, columnNames[i], null);
                case _:
                  throw new SQLiteException('Unknown column type ${type}', SQLiteResultCode.INTERNAL);
              }
            }
            status = step();
            if (status != SQLiteResultCode.ROW && status != SQLiteResultCode.DONE)
            {
              nextRowError = SQLiteException.fromConnection(owner.db.raw);
            }
            return data;

          case _:
            // Unreachable: errors are thrown above, before the status is read.
            throw new SQLiteException('Unexpected step result ${status}', SQLiteResultCode.INTERNAL);
        }
      }
    }
  }
}

/**
 * A value to bind, associated with its type.
 * @see `SQLiteStatement.toBindValue()`
 */
private enum BindValue
{
  BNull;
  BInt(value:Int);
  BInt64(value:Int64);
  BFloat(value:Float);
  BString(value:String);
  BBytes(value:Bytes);
}

/**
 * A checked value for one parameter.
 * Functions like `bindAll()` check each value before applying.
 */
private typedef Binding =
{
  var index:Int;
  var value:BindValue;
}
#end
