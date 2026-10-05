@IsTest
private class IndianMedicationCatalogProviderTest {

    @IsTest
    static void listsAllopathicProductsOnceAndSkipsAyurvedic() {
        insert new List<Medication>{
            new Medication(Name = 'Dolo 650mg Tablet'),
            new Medication(Name = 'Dolo  650mg  Tablet'),
            new Medication(Name = 'Triphala Churna', Main_Indications__c = 'Anaha')
        };

        IndianMedicationCatalogProvider.Request req = new IndianMedicationCatalogProvider.Request();
        List<IndianMedicationCatalogProvider.Response> res =
            IndianMedicationCatalogProvider.getCatalogue(new List<IndianMedicationCatalogProvider.Request>{ req });

        String catalogue = res[0].Prompt;
        Assert.areEqual(1, catalogue.split('\n').size(), 'Whitespace duplicates collapse to one product');
        Assert.isTrue(catalogue.contains('Dolo 650mg Tablet'));
        Assert.isFalse(catalogue.contains('Triphala'), 'Ayurvedic entries are excluded');
    }
}