module webtank.datctrl.record_set_range;

mixin template RecordSetRangeImpl()
{
	static class Range: RangeIface
	{
		private RecordSetIface _rs;
		private size_t _index = 0;

		this(RecordSetIface rs) {
			_rs = rs;
		}

		template _opApplyImpl(Rec, bool withIndex)
		{
			static if( withIndex ) {
				alias DelegateType = scope int delegate(size_t, Rec);
			} else {
				alias DelegateType = scope int delegate(Rec);
			}

			int _opApplyImpl(DelegateType dg)
			{
				int result = 0;
				foreach( i; 0.._rs.length )
				{
					static if( withIndex ) {
						result = dg(i, _rs.getRecord(i));
					} else {
						result = dg(_rs.getRecord(i));
					}
					if (result)
						break;
				}
				return result;
			}
		}

		public override {
			bool empty() @property {
				return _index >= _rs.length;
			}

			RecordIface front() @property {
				return _rs.getRecord(_index);
			}

			RecordIface moveFront() {
				assert(false, `Not implemented yet!`);
			}

			void popFront() {
				_index++;
			}

			static if( isWriteableFlag )
			{
				int opApply(scope int delegate(IBaseRecord) dg) {
					return _opApplyImpl!(IBaseRecord, false)(dg);
				}

				int opApply(scope int delegate(size_t, IBaseRecord) dg) {
					return _opApplyImpl!(IBaseRecord, true)(dg);
				}
			}

			int opApply(scope int delegate(RecordIface) dg) {
				return _opApplyImpl!(RecordIface, false)(dg);
			}

			int opApply(scope int delegate(size_t, RecordIface) dg) {
				return _opApplyImpl!(RecordIface, true)(dg);
			}
		}
	}
}