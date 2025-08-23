class GreetingUtils {
  static String getTimeOfDay({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now();
    final hour = now.hour;
    
    if (hour < 4) {
      return 'Night';
    } else if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }
}