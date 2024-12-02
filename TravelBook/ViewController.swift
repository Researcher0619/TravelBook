//
//  ViewController.swift
//  TravelBook
//
//  Created by Özkan CEYHAN on 29.11.2024.
//

import UIKit
import MapKit   // Harita işlemleri için kullanılır
import CoreLocation // Kullanıcının konumunu almak için gerekli framework
import CoreData // Veritabanı işlemleri için kullanılan framework

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapView: MKMapView! // Harita görünümünü göstermek için MKMapView bileşeni
    @IBOutlet weak var nameText: UITextField! // Kullanıcının yer adı gireceği metin alanı
    @IBOutlet weak var commentText: UITextField! // Kullanıcının yorum gireceği metin alanı
    
    var chosenLatitude: Double? // Kullanıcının seçtiği enlem
    var chosenLongitude: Double? // Kullanıcının seçtiği boylam
    
    var selectedTitle = "" // Kullanıcı tarafından seçilen yerin başlığı
    var selectedTitleId : UUID? // Veritabanındaki benzersiz kimlik (UUID)
    
    var locationManager = CLLocationManager() // Kullanıcının konumunu yönetecek nesne
    
    var annotationTitle = "" // Harita üzerindeki işaretçinin başlığı
    var annotationSubtitle = "" // Harita üzerindeki işaretçinin alt başlığı
    var annotationLatitude =  Double() // Harita işaretçisinin enlemi
    var annotationLongitude = Double() // Harita işaretçisinin boylamı
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self // Harita olaylarını yönetmek için delegate atanıyor
        locationManager.delegate = self // Konum yöneticisinin delegate'i atanıyor
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // En yüksek doğruluk seviyesi isteniyor
        locationManager.requestWhenInUseAuthorization() // Kullanıcıdan uygulama açıkken konum izni isteniyor
        locationManager.startUpdatingLocation() // Konum güncellemeleri başlatılıyor
        
        // Harita üzerine uzun basma hareketi için gesture tanımlanıyor
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocation(gestureRecognizer:)))
        longPressGestureRecognizer.minimumPressDuration = 3 // Uzun basma süresi 3 saniye olarak ayarlandı
        mapView.addGestureRecognizer(longPressGestureRecognizer) // Gesture tanıyıcı haritaya ekleniyor
        
        if selectedTitle != "" {
            // Daha önce kaydedilmiş bir yeri yüklemek için Core Data'dan veri getiriliyor
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            let idString  = selectedTitleId!.uuidString
            fetchRequest.predicate = NSPredicate(format: "id == %@", idString) // Sadece ilgili kaydı getirmek için filtre
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                let results = try context.fetch(fetchRequest)
                if results.count > 0 {
                    for result in results as! [NSManagedObject] {
                        if let title = result.value(forKey: "title") as? String {
                            annotationTitle = title
                            if let subtitle = result.value(forKey: "subtitle") as? String {
                                annotationSubtitle = subtitle
                                if let latitude = result.value(forKey: "latitude") as? Double {
                                    annotationLatitude = latitude
                                    if let longitude = result.value(forKey: "longitude") as? Double {
                                        annotationLongitude = longitude
                                        
                                        // Haritaya işaretçi ekleniyor
                                        let annotation = MKPointAnnotation()
                                        annotation.title = annotationTitle
                                        annotation.subtitle = annotationSubtitle
                                        let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
                                        annotation.coordinate = coordinate
                                        mapView.addAnnotation(annotation)
                                        
                                        // Metin alanları dolduruluyor
                                        nameText.text = annotationTitle
                                        commentText.text = annotationSubtitle
                                        
                                        locationManager.stopUpdatingLocation() // Konum güncellemeleri durduruluyor
                                        
                                        // Haritayı belirli bir yakınlaştırma seviyesiyle güncelle
                                        let span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                                        let region = MKCoordinateRegion(center: coordinate, span: span)
                                        mapView.setRegion(region, animated: true)
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Error")
            }
        }
    }
    
    // Kullanıcı haritaya uzun basınca bu fonksiyon çağrılır
    @objc func chooseLocation(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: self.mapView) // Dokunulan nokta
            let touchCoordinates = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView) // Harita koordinatlarına dönüştürme
            self.chosenLatitude = touchCoordinates.latitude
            self.chosenLongitude = touchCoordinates.longitude
            
            // İşaretçi (pin) ekleme
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchCoordinates
            annotation.title = nameText.text
            annotation.subtitle = commentText.text
            self.mapView.addAnnotation(annotation)
        }
    }
    
    // Konum güncellendiğinde çağrılan fonksiyon
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if selectedTitle == "" { // Yeni bir yer ekleniyorsa
            let location = CLLocationCoordinate2D(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude)
            let span = MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            let region = MKCoordinateRegion(center: location, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Kullanıcının konumunu gösteren annotation'u atla
        guard !(annotation is MKUserLocation) else {
            return nil
        }

        // Annotation görünümünü yeniden kullanmak için bir tanımlayıcı
        let reuseID = "myAnnotation"
        
        // Annotation görünümünü deque kullanarak yeniden kullan veya yenisini oluştur
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            // Yeni bir MKMarkerAnnotationView oluştur
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            annotationView?.canShowCallout = true
            annotationView?.markerTintColor = .red
            
            // Detay düğmesini sağ callout için ekle
            let button = UIButton(type: .detailDisclosure)
            annotationView?.rightCalloutAccessoryView = button
        } else {
            // Mevcut annotation görünümünü güncelle
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }

    
    // MapView'de bir annotation'a tıklandığında aksiyon alınmasını sağlar
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        // Eğer seçilen başlık boş değilse işlemleri başlat
        if selectedTitle != "" {
            // Kullanıcı tarafından seçilen annotation'ın enlem ve boylam bilgileriyle bir konum oluşturulur
            let requestLocation = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            
            // Geocoder kullanarak bu konumun ters geokodlama işlemi yapılır (koordinatları bir adres bilgisine dönüştürme)
            CLGeocoder().reverseGeocodeLocation(requestLocation) { (placemarks, error) in
                // Geocoder'dan dönen adres bilgileri placemarks dizisinde bulunur
                if let placemark = placemarks {
                    // Eğer adres bilgileri mevcut ve en az bir sonuç varsa
                    if placemark.count > 0 {
                        // İlk placemark'ı kullanarak bir MKPlacemark nesnesi oluştur
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        
                        // MKPlacemark nesnesinden bir MKMapItem oluştur
                        let item = MKMapItem(placemark: newPlacemark)
                        
                        // MapItem'e bir isim atanır (annotation'ın başlığı)
                        item.name = self.annotationTitle
                        
                        // Haritada yön tarifi seçeneği için gerekli parametreler tanımlanır
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                        
                        // MKMapItem kullanılarak Haritalar uygulaması açılır ve navigasyon başlatılır
                        item.openInMaps(launchOptions: launchOptions)
                    }
                }
            }
        }
    }

    
    
    
    @IBAction func saveButton(_ sender: Any) {
        // Core Data üzerinden yeni bir yer kaydetmek için işlemler
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Places", into: context)
        
        if let isimAlani = nameText.text, !isimAlani.isEmpty,
           let yorumAlani = commentText.text, !yorumAlani.isEmpty {
            if let latitude = chosenLatitude, let longitude = chosenLongitude {
                newPlace.setValue(isimAlani, forKey: "title")
                newPlace.setValue(yorumAlani, forKey: "subtitle")
                newPlace.setValue(latitude, forKey: "latitude")
                newPlace.setValue(longitude, forKey: "longitude")
                newPlace.setValue(UUID(), forKey: "id") // Benzersiz ID atanıyor
                
                do {
                    try context.save()
                    print("Data saved successfully!")
                    // Bildirim gönderiliyor
                    NotificationCenter.default.post(name:NSNotification.Name("newPlace"), object: nil)
                                    
                    // Bir önceki ekrana dön
                    self.navigationController?.popViewController(animated: true)
                } catch {
                    print("Error saving data: \(error.localizedDescription)")
                }
            } else {
                let alert = UIAlertController(title: "Error", message: "Please select a location on the map.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            let alert = UIAlertController(title: "Error", message: "Please fill in all fields and choose a location!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
}
