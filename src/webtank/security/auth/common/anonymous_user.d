module webtank.security.auth.common.anonymous_user;

import webtank.security.auth.iface.user_identity: IUserIdentity;

///Класс представляет удостоверение анонимного пользователя
class AnonymousUser: IUserIdentity
{
public:
	override {
		string id() {
			return null;
		}
		
		string name() {
			return null;
		}
		
		string[string] data() {
			return null;
		}
		
		bool isAuthenticated() {
			return false;
		}
		
		bool isInRole(string roleName) {
			return false;
		}

		void invalidate() {}
	}
}
