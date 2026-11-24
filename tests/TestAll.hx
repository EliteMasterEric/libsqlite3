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

		runner.addCase(new TestUseAfterClose());
		runner.addCase(new TestNoTruncation());
		runner.addCase(new TestReturnCodes());
		runner.addCase(new TestPrepareTrailingText());

		Report.create(runner, SuccessResultsDisplayMode.AlwaysShowSuccessResults, HeaderDisplayMode.NeverShowHeader);
		runner.run();
	}
}
