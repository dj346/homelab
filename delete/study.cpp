class ItemType {
    private:
        int value;
    public:
        ItemType();
        ItemType(int val);
        void Initialize(int val);
        int GetValue() const;
        bool operator<(const ItemType& other) const;
        bool operator==(const ItemType& other) const;
};

class SortedType {
    private:
        NodeType* head;
        int length;
    public:
        SortedType();
        ~SortedType();
        bool IsFull() const;
        int GetLength() const;
        void MakeEmpty();
        void PutItem(const ItemType& item);
        bool DeleteItem(const ItemType& item);
        bool RetrieveItem(const ItemType& item, ItemType& foundItem) const;
        void PrintForward() const;
        void PrintReverse() const;
    };

struct NodeType {
    ItemType info;
    NodeType* next;
};

bool SortedType::DeleteItem(const ItemType& item) {
    NodeType* curr = head->next;
    NodeType* prev = head;
    NodeType* temp = nullptr;

    while (curr != nullptr) {
        

        if (curr->info == item) {
            temp = curr;

            prev->next = curr->next;

            delete temp;
            length--;
        }

        prev->next = curr;
        curr = curr->next;
    }
}