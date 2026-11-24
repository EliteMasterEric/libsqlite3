package;

import utest.ui.common.HeaderDisplayMode;
import utest.ui.Report;
import utest.Runner;
import cases.*;
import regression.*;

class TestAll {
	public static function main() {
		var runner = new Runner();

		runner.addCase(new TestQuery());
		runner.addCase(new TestPreparedQuery());
		runner.addCase(new TestInsert());
		runner.addCase(new TestPreparedInsert());
		runner.addCase(new TestInnerJoin());
		runner.addCase(new TestPreparedInnerJoin());
		runner.addCase(new TestBlob());
		runner.addCase(new TestPreparedBlob());
		runner.addCase(new TestTypes());
		runner.addCase(new TestStatementReuse());
		runner.addCase(new TestErrors());
		runner.addCase(new TestConnection());

		runner.addCase(new TestUseAfterClose());
		runner.addCase(new TestNoTruncation());
		runner.addCase(new TestReturnCodes());
		runner.addCase(new TestPrepareTrailingText());
		runner.addCase(new TestFailedOpen());
		runner.addCase(new TestBindBytes());
		runner.addCase(new TestQueryErrors());
		runner.addCase(new TestUnclosedDatabase());
		runner.addCase(new TestNullBind());
		runner.addCase(new TestExecuteStatementRows());
		runner.addCase(new TestExecuteWithoutReset());
		runner.addCase(new TestStaleIterator());
		runner.addCase(new TestSchemaChange());
		runner.addCase(new TestStepErrorFlag());

		Report.create(runner, SuccessResultsDisplayMode.AlwaysShowSuccessResults, HeaderDisplayMode.NeverShowHeader);
		runner.run();
	}
}
