import 'package:flutter/material.dart';
import 'package:mobilproje/homePage.dart';
import 'package:mobilproje/screens/login_screen.dart';

class StartUp extends StatelessWidget{
  const StartUp({Key?key}): super(key: key);

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text('AI Asistanın',
                  style: TextStyle(
                      fontSize:24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary
                  ),
                ),

                SizedBox(height: 16,),
                Text('Günlük yaşamınızı kolaylaştırmak için buradayız. AI Asistanınıza soru sorun, öneri alın ve üretkenliğinizi artırın!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary
                  ),
                )
              ],
            ),
            SizedBox(height: 32,),
            Image.asset('assets/onboarding.png'),
            SizedBox(height: 32,),
            ElevatedButton(
              onPressed: (){
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder:(context)=>const LoginScreen()),
                        (route)=>false

                );
              },

              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16,horizontal: 32)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Continue'),
                  SizedBox(width: 8,),
                  Icon(Icons.arrow_forward)
                ],
              ),
            )

          ],
        ),
      ),
    );
  }
}