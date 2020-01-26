module webtank.security.auth.core.consts;

enum uint minLoginLength = 3;  // Минимальная длина логина
enum uint minPasswordLength = 8;  // Минимальная длина пароля
enum size_t sessionLifetime = 180; // Время жизни сессии в минутах
enum size_t emailConfirmDaysLimit = 3;  // Время на подтверждение адреса электронной почты пользователем