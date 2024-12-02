//
//  ListViewController.swift
//  TravelBook
//
//  Created by Özkan CEYHAN on 1.12.2024.
//

import UIKit
import CoreData

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    // Verilerin saklanacağı diziler
    var titleArray: [String] = [] // Mekan başlıkları için dizi
    var idArray: [UUID] = [] // Mekanlara ait benzersiz ID'ler için dizi
    
    // Seçilen mekan bilgileri
    var chosenTitle = "" // Seçilen mekan başlığı
    var chosenTitleId: UUID? // Seçilen mekanın ID'si
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Navigasyon barına "Ekle" butonunu ekle
        navigationController?.navigationBar.topItem?.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonClicked))
        
        // TableView delegesi ve veri kaynağı olarak bu sınıfı ayarla
        tableView.delegate = self
        tableView.dataSource = self
        
        // Core Data'dan verileri yükle
        getData()
    }
    
    // ViewController dan buraya geçtiğinde güncel tabloyu göstermesi için yeniden çalıştırmak yerine
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(getData), name: NSNotification.Name("newPlace"),  object: nil)
    }
    
    // Core Data'dan verileri çekme işlemi
    @objc func getData() {
        // AppDelegate'den Core Data context'i al
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        // Veri çekmek için bir NSFetchRequest oluştur
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
        request.returnsObjectsAsFaults = false // Verileri tam olarak almak istiyoruz
        
        do {
            // Fetch işlemini gerçekleştir
            let results = try context.fetch(request)
            
            if results.count > 0 {
                
                // Önceki verileri temizle
                // Duplica verileri engellemek için
                self.titleArray.removeAll(keepingCapacity: false)
                self.idArray.removeAll(keepingCapacity: false)
                
                // Gelen verileri işle
                for result in results as! [NSManagedObject] {
                    if let title = result.value(forKey: "title") as? String {
                        self.titleArray.append(title) // Başlığı diziye ekle
                    }
                    if let id = result.value(forKey: "id") as? UUID {
                        self.idArray.append(id) // ID'yi diziye ekle
                    }
                }
                // TableView'i yeniden yükle
                tableView.reloadData()
            }
        } catch {
            // Hata durumunda konsola hata mesajı yazdır
            print("Error fetching data")
        }
    }
    
    // "+" butonuna tıklandığında yeni bir mekan eklemek için çağrılır
    @objc func addButtonClicked() {
        chosenTitle = "" // Seçilen başlığı sıfırla
        performSegue(withIdentifier: "toViewController", sender: nil) // Geçişi başlat
    }
    
    // TableView'deki satır sayısını belirler
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleArray.count // Başlık sayısı kadar satır döndür
    }
    
    // TableView'deki her bir hücrenin içeriğini ayarlar
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell() // Yeni bir hücre oluştur
        cell.textLabel?.text = titleArray[indexPath.row] // Hücrenin metnini başlık dizisinden al
        return cell
    }
    
    // Bir satır seçildiğinde çalışır
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        chosenTitle = titleArray[indexPath.row] // Seçilen başlığı al
        chosenTitleId = idArray[indexPath.row] // Seçilen ID'yi al
        performSegue(withIdentifier: "toViewController", sender: nil) // Geçişi başlat
    }
    
    // Segue işlemi gerçekleşmeden önce çalışır
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toViewController" {
            // Hedef ViewController'a veri gönder
            let destinationVC = segue.destination as! ViewController
            
            destinationVC.selectedTitle = chosenTitle // Seçilen başlığı aktar
            destinationVC.selectedTitleId = chosenTitleId // Seçilen ID'yi aktar
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Core Data'dan veriyi sil
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            let idString = idArray[indexPath.row].uuidString
            fetchRequest.predicate = NSPredicate(format: "id == %@", idString)
            
            do {
                let results = try context.fetch(fetchRequest)
                if results.count > 0 {
                    for result in results as! [NSManagedObject] {
                        context.delete(result)
                        titleArray.remove(at: indexPath.row) // Diziden veriyi sil
                        idArray.remove(at: indexPath.row)
                        tableView.deleteRows(at: [indexPath], with: .fade) // Tablodan sil
                    }
                    try context.save() // Core Data'yı güncelle
                }
            } catch {
                print("Error deleting data")
            }
        }
    }

    
    
}
