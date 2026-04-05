import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/manage_receipt_screen.dart';
import 'package:flutter_application_1/main_screens/preorder_screen.dart';
import 'package:flutter_application_1/main_screens/manage_furniture.dart';

class Navigation extends StatelessWidget{
  const Navigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            color: Color.fromRGBO(215, 199, 187, 1.0),
            child: Center(
              child: Column(
                children: <Widget>[
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://scontent.fmnl17-2.fna.fbcdn.net/v/t39.30808-6/565319095_1128726149395643_8094975518170593394_n.jpg?_nc_cat=107&ccb=1-7&_nc_sid=1d70fc&_nc_eui2=AeGz9tN_4QcssA9gLdQBlksJYjb1YxdZG-tiNvVjF1kb6yiQ6KbwAJHEAet14aFFr74ooX1wDQJD7eSmbPiCxfny&_nc_ohc=yi8wHpiTz1wQ7kNvwE1XpJW&_nc_oc=AdlKhN1ycFQUZKoAGwIYSRW3BzWljC7pIjByyxMksl1Vx7MCvzfDLksib8iEY7_LgVE&_nc_zt=23&_nc_ht=scontent.fmnl17-2.fna&_nc_gid=K_RFiHTgaVejnzxBjsHyNw&oh=00_AfvdCR2ShmZV3sIe-9NjrD_nJd7aPVk2kk0rTGrOOUTMlQ&oe=69A4C772'
                          ),
                        fit: BoxFit.fill
                      ),  
                    ),
                  ),
                ],
              ),
            ),
          ),
          //Manage Receipt navigation
          ListTile(
            leading: Icon(Icons.receipt),
            title: Text('Manage Receipts'),
            onTap: (){ Navigator.of(context).pushNamed(ManageReceipt.routeName);},
          ),
          //pre order detail navigation
          ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('Pre Order Detail'),
            onTap: (){ Navigator.of(context).pushNamed(Preorder.routeName);},
          ),
          //Manage Product navigation
          ListTile(
            leading: Icon(Icons.local_shipping),
            title: Text('Manage Products'),
            onTap: (){ Navigator.of(context).pushNamed(ManageFurniture.routeName);},
          ),
          //Logout navigation
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Logout'),
            onTap: null,
          ),
        ],
      ),
    );
  }
}