import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as devtools show log;

extension Log on Object {
  void log() => devtools.log(toString());
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider<PersonsBloc>(
        create: (context) => PersonsBloc(),
        child: const HomePage(),
      ),
    );
  }
}

@immutable
abstract class LoadAction {
  const LoadAction();
}

@immutable
class LoadPersonAction implements LoadAction {
  final PersonUrl url;

  const LoadPersonAction({required this.url}) : super();
}

enum PersonUrl {
  persons1,
  persons2,
}

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.persons1:
        return 'http://127.0.0.1:5500/apis/persons1.json';
      case PersonUrl.persons2:
        return 'http://127.0.0.1:5500/apis/persons2.json';
      default:
        return 'http://127.0.0.1:5500/apis/persons1.json';
    }
  }
}

@immutable
class Person {
  final String name;
  final int age;

  const Person({required this.name, required this.age});

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;

  @override
  String toString() {
    return 'Person(name: $name, age: $age)';
  }
}

Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url)) // get request
    .then((req) => req.close()) // get response
    .then((res) =>
        res.transform(utf8.decoder).join()) // covert response --> string
    .then((str) => json.decode(str) as List<dynamic>) // convert string --> list
    .then((list) =>
        list.map((json) => Person.fromJson(json))); // convert list --> json

@immutable
class FetchResult {
  final Iterable<Person> persons;
  final bool isRetrieveFromCache;

  const FetchResult({required this.persons, required this.isRetrieveFromCache});

  @override
  String toString() =>
      'FetchResult (isRetrieveFromCache = $isRetrieveFromCache, person = $persons)';
}

class PersonsBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};
  PersonsBloc() : super(null) {
    on<LoadPersonAction>((event, emit) async {
      /// [event] the input of bloc
      /// [emit] the output of bloc
      final url = event.url;
      if (_cache.containsKey(url)) {
        // have a value of cache
        final cachePerson = _cache[url];
        final result =
            FetchResult(persons: cachePerson!, isRetrieveFromCache: true);
        emit(result);
      } else {
        final persons = await getPersons(url.urlString);
        _cache[url] = persons;
        final result =
            FetchResult(persons: persons, isRetrieveFromCache: false);
        emit(result);
      }
    });
  }
}

extension Subscript<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                  onPressed: () {
                    context
                        .read<PersonsBloc>()
                        .add(const LoadPersonAction(url: PersonUrl.persons1));
                  },
                  child: const Text('Load json #1')),
              TextButton(
                  onPressed: () {
                    context
                        .read<PersonsBloc>()
                        .add(const LoadPersonAction(url: PersonUrl.persons2));
                  },
                  child: const Text('Load json #2')),
            ],
          ),
          BlocBuilder<PersonsBloc, FetchResult?>(
            buildWhen: (previous, current) {
              return previous?.persons != current?.persons;
            },
            builder: (context, state) {
              state?.log();
              final persons = state?.persons;
              if (persons == null) {
                return const SizedBox.shrink();
              } else {
                return Expanded(
                  child: ListView.builder(
                      itemCount: persons.length,
                      itemBuilder: (context, index) {
                        final person = persons[index]!;
                        return ListTile(
                          title: Text('Name ${person.name}'),
                          subtitle: Text('Age ${person.age}'),
                        );
                      }),
                );
              }
            },
          )
        ],
      ),
    );
  }
}
